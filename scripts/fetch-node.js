#!/usr/bin/env node
/*
 * fetch-node.js — fetch an HTTPS URL using Node's own TLS stack.
 *
 * Why this exists: on some hosts (e.g. AltLinux with a GOST-patched OpenSSL, or
 * behind a TLS-intercepting proxy) the system `curl`/OpenSSL cannot complete a
 * TLS handshake to nodejs.org — it fails at `x509_pubkey_decode:unsupported
 * algorithm`, even with `-k` and even when bypassing the proxy. `nvm` shells out
 * to that curl, so `nvm install <version>` fails. Node's bundled OpenSSL accepts
 * the same certificates (this is why `npm install` keeps working), so we do the
 * download with Node instead. This is the fallback path for the isolated Node
 * installer — see `fetch_node_via_node_tls` in lib/nvm/install.sh.
 *
 * Usage:  node fetch-node.js <httpsUrl> [outFile]
 *   - writes the body to <outFile>, or to stdout if omitted
 *   - exit 0 on HTTP 200, non-zero otherwise
 *
 * Proxy: read from ICLAUDE_PROXY_URL, then HTTPS_PROXY/https_proxy. Supports an
 * HTTPS proxy (TLS to the proxy, then CONNECT + inner TLS to the target =
 * TLS-over-TLS) and a plain HTTP proxy (TCP + CONNECT). With no proxy set, a
 * direct TLS connection is made. Certificate verification is disabled because
 * the whole point is a host whose certs the platform cannot verify; download
 * integrity is instead checked by the caller via SHASUMS256.txt (sha256).
 */
'use strict';
const tls = require('tls');
const net = require('net');
const fs = require('fs');

function fail(msg, code) {
  process.stderr.write(msg + '\n');
  process.exit(code);
}

const targetArg = process.argv[2];
const outFile = process.argv[3] || null;
if (!targetArg) fail('usage: fetch-node.js <httpsUrl> [outFile]', 2);

const target = new URL(targetArg);
if (target.protocol !== 'https:') fail('only https URLs are supported', 2);

const proxyRaw = process.env.ICLAUDE_PROXY_URL || process.env.HTTPS_PROXY || process.env.https_proxy || '';
const proxy = proxyRaw ? new URL(proxyRaw) : null;

// Open the tunnel socket to the target (through a proxy when configured).
function openTunnel(cb) {
  if (!proxy) {
    // Direct: TLS straight to the target host.
    const s = tls.connect(
      { host: target.hostname, port: 443, servername: target.hostname, rejectUnauthorized: false },
      () => cb(s)
    );
    s.on('error', (e) => fail('direct tls error: ' + e.message, 3));
    return;
  }

  const proxyHost = proxy.hostname;
  const proxyPort = proxy.port || (proxy.protocol === 'https:' ? 443 : 8080);
  const proxyAuth = proxy.username
    ? 'Proxy-Authorization: Basic ' +
      Buffer.from(decodeURIComponent(proxy.username) + ':' + decodeURIComponent(proxy.password)).toString('base64') +
      '\r\n'
    : '';

  const onProxyReady = (proxySock) => {
    proxySock.write(
      'CONNECT ' + target.hostname + ':443 HTTP/1.1\r\n' +
      'Host: ' + target.hostname + ':443\r\n' + proxyAuth + '\r\n'
    );
    let header = '';
    const onData = (chunk) => {
      header += chunk.toString('binary');
      if (header.indexOf('\r\n\r\n') === -1) return;
      proxySock.removeListener('data', onData);
      const statusLine = header.split('\r\n')[0];
      if (!/ 200 /.test(statusLine)) fail('proxy CONNECT failed: ' + statusLine, 4);
      // Inner TLS to the real target, layered over the proxy connection.
      const inner = tls.connect(
        { socket: proxySock, servername: target.hostname, rejectUnauthorized: false },
        () => cb(inner)
      );
      inner.on('error', (e) => fail('inner tls error: ' + e.message, 6));
    };
    proxySock.on('data', onData);
    proxySock.on('error', (e) => fail('proxy socket error: ' + e.message, 3));
  };

  if (proxy.protocol === 'https:') {
    const s = tls.connect(
      { host: proxyHost, port: proxyPort, servername: proxyHost, rejectUnauthorized: false },
      () => onProxyReady(s)
    );
    s.on('error', (e) => fail('proxy tls error: ' + e.message, 3));
  } else {
    const s = net.connect(proxyPort, proxyHost, () => onProxyReady(s));
    s.on('error', (e) => fail('proxy tcp error: ' + e.message, 3));
  }
}

openTunnel((sock) => {
  sock.write(
    'GET ' + target.pathname + target.search + ' HTTP/1.1\r\n' +
    'Host: ' + target.hostname + '\r\n' +
    'User-Agent: iclaude-fetch\r\n' +
    'Accept: */*\r\n' +
    'Connection: close\r\n\r\n'
  );

  let headParsed = false;
  let headBuf = Buffer.alloc(0);
  let status = 0;
  let received = 0;
  const out = outFile ? fs.createWriteStream(outFile) : null;
  const chunks = [];

  const writeBody = (buf) => {
    if (!buf.length) return;
    received += buf.length;
    if (out) out.write(buf);
    else chunks.push(buf);
  };

  sock.on('data', (d) => {
    if (headParsed) { writeBody(d); return; }
    headBuf = Buffer.concat([headBuf, d]);
    const hi = headBuf.indexOf('\r\n\r\n');
    if (hi === -1) return;
    const head = headBuf.slice(0, hi).toString();
    status = parseInt(head.split('\r\n')[0].split(' ')[1], 10) || 0;
    headParsed = true;
    writeBody(headBuf.slice(hi + 4));
  });

  sock.on('end', () => {
    const done = () => {
      process.stderr.write('HTTP ' + status + ', ' + received + ' bytes' + (outFile ? ' -> ' + outFile : '') + '\n');
      process.exit(status === 200 ? 0 : 5);
    };
    if (out) out.end(done);
    else { process.stdout.write(Buffer.concat(chunks)); done(); }
  });
  sock.on('error', (e) => fail('read error: ' + e.message, 6));
});
