const crypto = require('crypto');

const DEFAULT_STORAGE_TOKEN_RESOURCE = 'https://storage.azure.com/';
const DEFAULT_STORAGE_BLOB_DNS_SUFFIX = 'blob.core.windows.net';
const STORAGE_API_VERSION = '2020-12-06';
const SAS_VERSION = '2020-12-06';
const CANONICAL_PERMISSION_ORDER = 'racwdxltmeop';

module.exports = async function (context, req) {
  try {
    if (!isAuthorized(req)) {
      context.res = jsonResponse(401, {
        error: 'Unauthorized',
        message: 'Missing or invalid broker secret.'
      });
      return;
    }

    const body = normalizeBody(req.body);
    const storageAccountName = String(body.storageAccountName || '');
    const containerName = String(body.containerName || '');
    const ttlMinutes = body.ttlMinutes === undefined || body.ttlMinutes === ''
      ? 1440
      : Number.parseInt(body.ttlMinutes, 10);
    const permissions = normalizePermissions(String(body.permissions || 'racwdl'));

    if (!/^[a-z0-9]{3,24}$/.test(storageAccountName)) {
      throw new Error('storageAccountName must be a valid Azure Storage account name.');
    }
    if (!/^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])?$/.test(containerName)) {
      throw new Error('containerName must be a valid Azure Blob container name.');
    }
    if (!Number.isInteger(ttlMinutes) || ttlMinutes < 5 || ttlMinutes > 10080) {
      throw new Error('ttlMinutes must be between 5 and 10080 (7 days).');
    }

    const signedStart = formatAzureTime(new Date(Date.now() - 15 * 60 * 1000));
    const signedExpiry = formatAzureTime(new Date(Date.now() + ttlMinutes * 60 * 1000));
    const storageTokenResource = getStorageTokenResource();
    const blobServiceHost = getBlobServiceHost(storageAccountName);
    const token = await getManagedIdentityToken(storageTokenResource);
    const delegationKey = await getUserDelegationKey(blobServiceHost, token, signedStart, signedExpiry);
    const sasQuery = createContainerUserDelegationSas({
      storageAccountName,
      containerName,
      permissions,
      signedStart,
      signedExpiry,
      delegationKey
    });

    context.res = jsonResponse(200, {
      sasUrl: `https://${blobServiceHost}/${containerName}?${sasQuery}`,
      expiresOnUtc: signedExpiry,
      storageAccountName,
      containerName,
      permissions,
      authMode: 'user_delegation_sas',
      correlationId: String(body.correlationId || ''),
      deviceId: String(body.deviceId || ''),
      deviceName: String(body.deviceName || '')
    });
  } catch (error) {
    context.log.error(error);
    context.res = jsonResponse(400, {
      error: 'SasGenerationFailed',
      message: error && error.message ? error.message : String(error)
    });
  }
};

function isAuthorized(req) {
  const expected = process.env.BROKER_SHARED_SECRET;
  if (!expected) {
    throw new Error('BROKER_SHARED_SECRET app setting is not configured.');
  }

  const provided = String(
    (req.query && (req.query.brokerCode || req.query.code)) ||
    (req.headers && (req.headers['x-broker-key'] || req.headers['x-cybertriage-broker-key'])) ||
    ''
  );

  const expectedBuffer = Buffer.from(expected, 'utf8');
  const providedBuffer = Buffer.from(provided, 'utf8');
  return expectedBuffer.length === providedBuffer.length && crypto.timingSafeEqual(expectedBuffer, providedBuffer);
}

function normalizeBody(body) {
  if (!body) {
    throw new Error('Request body is required.');
  }
  return typeof body === 'string' ? JSON.parse(body) : body;
}

function normalizePermissions(permissions) {
  const seen = new Set();
  for (const character of permissions) {
    if (!CANONICAL_PERMISSION_ORDER.includes(character)) {
      throw new Error(`Unsupported SAS permission '${character}'. Valid characters are ${CANONICAL_PERMISSION_ORDER}.`);
    }
    seen.add(character);
  }
  return [...CANONICAL_PERMISSION_ORDER].filter((character) => seen.has(character)).join('');
}

function formatAzureTime(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function getStorageTokenResource() {
  const resource = String(process.env.STORAGE_TOKEN_RESOURCE || DEFAULT_STORAGE_TOKEN_RESOURCE).trim();
  return resource.endsWith('/') ? resource : `${resource}/`;
}

function getBlobServiceHost(storageAccountName) {
  const suffix = String(process.env.STORAGE_BLOB_DNS_SUFFIX || DEFAULT_STORAGE_BLOB_DNS_SUFFIX).replace(/^\.+/, '').replace(/\/+$/, '');
  if (!/^[a-z0-9.-]+$/.test(suffix) || suffix.includes('..')) {
    throw new Error('STORAGE_BLOB_DNS_SUFFIX must be a valid DNS suffix such as blob.core.windows.net or blob.core.usgovcloudapi.net.');
  }
  return `${storageAccountName}.${suffix}`;
}

async function getManagedIdentityToken(resource) {
  const identityEndpoint = process.env.IDENTITY_ENDPOINT || process.env.MSI_ENDPOINT;
  if (!identityEndpoint) {
    throw new Error('Managed identity endpoint is not available.');
  }

  const url = new URL(identityEndpoint);
  url.searchParams.set('api-version', '2019-08-01');
  url.searchParams.set('resource', resource);

  const headers = {};
  if (process.env.IDENTITY_HEADER) {
    headers['X-IDENTITY-HEADER'] = process.env.IDENTITY_HEADER;
  } else if (process.env.MSI_SECRET) {
    headers.Secret = process.env.MSI_SECRET;
  }

  const response = await fetch(url, { headers });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Managed identity token request failed (${response.status}): ${text}`);
  }

  const tokenResponse = JSON.parse(text);
  if (!tokenResponse.access_token) {
    throw new Error('Managed identity token response did not include access_token.');
  }
  return tokenResponse.access_token;
}

async function getUserDelegationKey(blobServiceHost, accessToken, signedStart, signedExpiry) {
  const response = await fetch(`https://${blobServiceHost}/?restype=service&comp=userdelegationkey`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/xml',
      'x-ms-date': new Date().toUTCString(),
      'x-ms-version': STORAGE_API_VERSION
    },
    body: `<?xml version="1.0" encoding="utf-8"?><KeyInfo><Start>${signedStart}</Start><Expiry>${signedExpiry}</Expiry></KeyInfo>`
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Get User Delegation Key failed (${response.status}): ${text}`);
  }

  return {
    signedObjectId: getXmlValue(text, 'SignedOid'),
    signedTenantId: getXmlValue(text, 'SignedTid'),
    signedStart: getXmlValue(text, 'SignedStart'),
    signedExpiry: getXmlValue(text, 'SignedExpiry'),
    signedService: getXmlValue(text, 'SignedService'),
    signedVersion: getXmlValue(text, 'SignedVersion'),
    value: getXmlValue(text, 'Value')
  };
}

function getXmlValue(xml, name) {
  const match = xml.match(new RegExp(`<${name}>([^<]+)</${name}>`));
  if (!match) {
    throw new Error(`Get User Delegation Key response did not include ${name}.`);
  }
  return decodeXml(match[1]);
}

function decodeXml(value) {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function createContainerUserDelegationSas(options) {
  const canonicalizedResource = `/blob/${options.storageAccountName}/${options.containerName}`;
  const signedProtocol = 'https';
  const signedResource = 'c';
  const fields = [
    options.permissions,
    options.signedStart,
    options.signedExpiry,
    canonicalizedResource,
    options.delegationKey.signedObjectId,
    options.delegationKey.signedTenantId,
    options.delegationKey.signedStart,
    options.delegationKey.signedExpiry,
    options.delegationKey.signedService,
    options.delegationKey.signedVersion,
    '',
    '',
    '',
    '',
    signedProtocol,
    SAS_VERSION,
    signedResource,
    '',
    '',
    '',
    '',
    '',
    '',
    ''
  ];
  const signature = crypto
    .createHmac('sha256', Buffer.from(options.delegationKey.value, 'base64'))
    .update(fields.join('\n'), 'utf8')
    .digest('base64');

  const query = new URLSearchParams({
    sv: SAS_VERSION,
    spr: signedProtocol,
    st: options.signedStart,
    se: options.signedExpiry,
    sr: signedResource,
    sp: options.permissions,
    skoid: options.delegationKey.signedObjectId,
    sktid: options.delegationKey.signedTenantId,
    skt: options.delegationKey.signedStart,
    ske: options.delegationKey.signedExpiry,
    sks: options.delegationKey.signedService,
    skv: options.delegationKey.signedVersion,
    sig: signature
  });
  return query.toString();
}

function jsonResponse(status, body) {
  return {
    status,
    headers: { 'Content-Type': 'application/json' },
    body
  };
}