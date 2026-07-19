/**
 * Mosyle Free-tier UI network capture helper.
 *
 * Records the Mosyle UI's own fetch/XHR traffic so you can read the exact request
 * body a feature sends, and wire it up in MosyleFreeKit. See docs/ENDPOINTS.md.
 *
 * Paste into the DevTools Console WHILE SIGNED IN TO A FREE TENANT YOU ADMINISTER,
 * then perform Management actions (list devices, restart, lock, clear commands...).
 * Run mosyleCaptureHint() for a suggested sequence. When finished:
 *
 *   mosyleDumpCapture()
 *
 * Downloads mosyle-free-ui-capture.json. Read the requestBody of the mapping.php
 * call — that is the operation name and its fields.
 *
 * The capture contains your live session's traffic, including device identifiers.
 * Treat it as sensitive: keep it out of version control (artifacts/ is gitignored)
 * and do not paste it into issues.
 *
 * This only observes traffic the UI already generates. It does not replay requests,
 * and it deliberately ignores article.php and managerapi.mosyle.com.
 */
(function () {
  if (window.__mosyleCaptureInstalled) {
    console.log('Capture already installed. Perform UI actions, then mosyleDumpCapture()');
    return;
  }
  window.__mosyleCaptureInstalled = true;
  window.__mosyleCapture = [];

  const interesting = (url) => {
    const u = String(url);
    return (
      /myschool\.mosyle\.com/i.test(u) ||
      u.startsWith('/') ||
      u.startsWith('screens/') ||
      /scules|mdm|device|command|ajax/i.test(u)
    ) && !/article\.php|managerapi\.mosyle|google-analytics|hotjar|stripe/i.test(u);
  };

  const push = (entry) => {
    if (!interesting(entry.url)) return;
    window.__mosyleCapture.push({
      t: Date.now(),
      ...entry,
    });
    console.log('[mosyle-capture]', entry.method || 'GET', entry.url, entry.status || '');
  };

  const origFetch = window.fetch;
  window.fetch = async function (input, init) {
    const url = typeof input === 'string' ? input : input.url;
    const method = (init && init.method) || (input && input.method) || 'GET';
    let body = init && init.body;
    if (body && typeof body !== 'string') {
      try {
        body = body.toString();
      } catch (_) {
        body = '[non-string body]';
      }
    }
    const res = await origFetch.apply(this, arguments);
    let respText = '';
    try {
      respText = await res.clone().text();
    } catch (_) {}
    push({
      via: 'fetch',
      method,
      url,
      requestBody: body ? String(body).slice(0, 8000) : null,
      status: res.status,
      responseSample: respText.slice(0, 4000),
      contentType: res.headers.get('content-type'),
    });
    return res;
  };

  const XO = XMLHttpRequest.prototype.open;
  const XS = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) {
    this.__mos = { method, url };
    return XO.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function (body) {
    this.addEventListener('load', function () {
      push({
        via: 'xhr',
        method: this.__mos && this.__mos.method,
        url: this.__mos && this.__mos.url,
        requestBody: body ? String(body).slice(0, 8000) : null,
        status: this.status,
        responseSample: String(this.responseText || '').slice(0, 4000),
        contentType: this.getResponseHeader('content-type'),
      });
    });
    return XS.apply(this, arguments);
  };

  window.mosyleDumpCapture = function () {
    const payload = {
      capturedAt: new Date().toISOString(),
      tenantTitle: document.title,
      href: location.href,
      count: window.__mosyleCapture.length,
      requests: window.__mosyleCapture,
    };
    const url = URL.createObjectURL(
      new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
    );
    const a = document.createElement('a');
    a.href = url;
    a.download = 'mosyle-free-ui-capture.json';
    a.click();
    console.log(`Saved ${payload.count} requests → mosyle-free-ui-capture.json`);
    return payload;
  };

  window.mosyleCaptureHint = function () {
    console.log(`
Capture ready (${window.__mosyleCapture.length} so far). Suggested sequence on Free:
  1. Management → Devices Overview (loads device list)
  2. Select ONE test device → More → Restart (or Restart Device)
  3. Same device → Lock Device
  4. Same device → Clear Commands (if present)
  5. Optional: Wipe / Lost Mode / Assign (note if disabled)
Then: mosyleDumpCapture()
`);
  };

  console.log('Mosyle Free UI capture installed. Run mosyleCaptureHint() for steps.');
})();
