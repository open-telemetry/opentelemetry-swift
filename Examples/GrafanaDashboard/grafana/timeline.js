// The Timeline panel on the HackerNewsDemo dashboard. The panel (Business Charts) imports this
// module and calls it with its context; it returns the ECharts options.
// Grafana serves this file at /public/hackernews-demo/timeline.js (see docker-compose.yaml).
export default (context) => {
  // Gantt timeline over the merged spans and events: one lane per session, spans as bars from
  // start to end, events (start == end) as markers. Colored by instrumentation scope.
  // Clicking an item selects it and opens its details in a sidebar on the right of the page; a
  // sidebar on the left lists the sessions.
  const frame = context.panel.data.series[0];
  const col = (name) => {
    const f = frame && frame.fields.find((x) => x.name === name);
    return f ? Array.from(f.values) : [];
  };
  const starts = col('start'), ends = col('end'), texts = col('text'), scopes = col('scope'), sessions = col('session');
  const traceIds = col('traceId'), keys = col('key'), eventNames = col('eventName');
  // Log records are labeled with their event name, else their body, else their scope. The string
  // conversion turns a missing event name into "null".
  const textOf = (i) => {
    if (eventNames[i] && eventNames[i] !== 'null') return eventNames[i];
    if (texts[i]) return texts[i];
    return `[${scopes[i] || 'unknown'}]`;
  };

  // key is the span ID for spans (16 hex digits) and Loki's row id for log records.
  const rows = starts
    .map((s, i) => ({
      start: Number(s),
      end: Number(ends[i]),
      text: textOf(i),
      scope: scopes[i] || 'unknown',
      session: sessions[i] && sessions[i] !== 'null' ? sessions[i] : 'no session',
      traceId: traceIds[i] || '',
      key: keys[i] || '',
      isSpan: /^[0-9a-f]{16}$/.test(keys[i] || ''),
    }))
    .filter((r) => !Number.isNaN(r.start))
    .sort((a, b) => a.start - b.start);

  const { locationService, replaceVariables } = context.grafana;
  // The selection lives in the URL (var-trace/var-span/var-event), so the Events table's links
  // and the Back button select things too.
  // Spans are keyed by trace and span ID together, log records by Loki's row id.
  const selectionKey = () => {
    const q = locationService.getSearchObject();
    return q['var-span'] ? `${q['var-trace']}/${q['var-span']}` : q['var-event'] || '';
  };
  const keyOf = (r) => (r.isSpan ? `${r.traceId}/${r.key}` : r.key);
  let selected = selectionKey();

  // Lanes in order of first activity.
  const lanes = [];
  rows.forEach((r) => { if (!lanes.includes(r.session)) lanes.push(r.session); });

  // Overlapping spans in a lane go on separate sub-rows so none is hidden.
  const laneRows = {};
  rows.forEach((r) => {
    if (!r.isSpan) return;
    const ends = laneRows[r.session] || (laneRows[r.session] = []);
    let i = ends.findIndex((e) => e <= r.start);
    if (i === -1) { i = ends.length; ends.push(0); }
    ends[i] = r.end;
    r.subRow = i;
  });

  const theme = context.grafana.theme;
  const palette = ['#F2CC0C', '#8AB8FF', '#96D98D', '#FFB357', '#CA95E5', '#FADE2A', '#C0D8FF', '#FF7383'];
  const scopeList = [...new Set(rows.map((r) => r.scope))].sort();
  // Fixed colors for the demo's scopes, and one picked from the name for any other, so a scope
  // keeps its color whatever else is in the time range.
  const knownColors = {
    'io.opentelemetry.kscrash': '#F2495C',
    'io.opentelemetry.sessions': '#FF9830',
    'NSURLSession': '#5794F2',
    'HackerNewsDemo.Debug': '#73BF69',
    'HackerNewsDemo.IntegrationTest': '#B877D9',
  };
  const hash = (str) => [...str].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7);
  const colorOf = (scope) => knownColors[scope] || palette[hash(scope) % palette.length];

  const esc = (v) => String(v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const fmtTime = (t) => new Date(t).toLocaleTimeString([], { hour12: false }) + '.' + String(Math.floor(t % 1000)).padStart(3, '0');
  const fmtDur = (ms) => {
    if (ms < 1) return (ms * 1000).toFixed(0) + ' µs';
    if (ms < 1000) return ms.toFixed(1) + ' ms';
    return (ms / 1000).toFixed(2) + ' s';
  };

  // Each lane: a strip at the top for event markers, the rest for span bars.
  const renderItem = (params, api) => {
    const r = rows[api.value(0)];
    const lane = lanes.indexOf(r.session);
    const band = api.size([0, 1])[1];
    const top = api.coord([r.start, lane])[1] - band * 0.45;
    const eventStrip = Math.min(16, band * 0.2);
    const color = colorOf(r.scope);
    const isSelected = keyOf(r) === selected;
    // Dim everything else while something is selected.
    const opacity = !selected || isSelected ? 1 : 0.35;
    const outline = isSelected ? { stroke: theme.colors.text.primary, lineWidth: 2 } : {};
    const x0 = api.coord([r.start, lane])[0];
    if (!r.isSpan) {
      return { type: 'group', children: [
        { type: 'line', shape: { x1: x0, y1: top + 4, x2: x0, y2: top + eventStrip }, style: { stroke: color, lineWidth: 2, opacity } },
        { type: 'circle', shape: { cx: x0, cy: top + 4, r: isSelected ? 6 : 4 }, style: { fill: color, opacity, ...outline } },
      ] };
    }
    const spanTop = top + eventStrip + 2;
    const spanHeight = band * 0.9 - eventStrip - 2;
    const subRows = laneRows[r.session].length;
    const h = Math.max(3, spanHeight / subRows - 2);
    const y = spanTop + r.subRow * (spanHeight / subRows);
    const width = Math.max(2, api.coord([r.end, lane])[0] - x0);
    const showLabel = width > 60 && h >= 12;
    const label = { style: { text: r.text, fill: '#111', fontSize: 11, overflow: 'truncate', width: width - 6 } };
    return {
      type: 'rect',
      shape: { x: x0, y, width, height: h, r: 2 },
      style: { fill: color, opacity: 0.85 * opacity, ...outline },
      textContent: showLabel ? label : undefined,
      textConfig: { position: 'insideLeft' },
    };
  };

  const series = scopeList.map((scope) => ({
    name: scope,
    type: 'custom',
    renderItem,
    itemStyle: { color: colorOf(scope) },
    encode: { x: [1, 2], y: 3 },
    data: rows.map((r, i) => [i, r.start, Math.max(r.end, r.start), lanes.indexOf(r.session)]).filter((d) => rows[d[0]].scope === scope),
  }));

  // Sidebars: one element each on the page, shared by every run of this code (it reruns on each
  // refresh). Content is built from DOM nodes, never HTML strings, since it shows telemetry.
  const state = window.__hackerNewsDemoTimeline || (window.__hackerNewsDemoTimeline = {});
  const sidebar = (id, border) => {
    let node = document.getElementById(id);
    if (!node) {
      node = document.createElement('aside');
      node.id = id;
      document.body.appendChild(node);
    }
    Object.assign(node.style, {
      position: 'fixed', zIndex: '10', flexDirection: 'column', boxSizing: 'border-box', overflow: 'hidden',
      background: theme.colors.background.primary, color: theme.colors.text.primary, [border]: `1px solid ${theme.colors.border.weak}`,
      fontFamily: theme.typography.fontFamily, fontSize: '13px',
    });
    return node;
  };
  // localStorage can be unavailable (private windows, blocked storage); fall back to false.
  const readFlag = (key) => {
    try {
      return localStorage.getItem(key) === 'true';
    } catch (e) {
      return false;
    }
  };
  const writeFlag = (key, value) => {
    try {
      localStorage.setItem(key, value);
    } catch (e) {}
  };
  const DETAILS_JSON_KEY = 'hackernews-demo.details-json';
  const SESSIONS_COLLAPSED_KEY = 'hackernews-demo.sessions-collapsed';
  const drawer = sidebar('hackernews-demo-details', 'borderLeft');
  const sessionsBar = sidebar('hackernews-demo-sessions', 'borderRight');
  sessionsBar.dataset.collapsed = readFlag(SESSIONS_COLLAPSED_KEY);

  // Split the page instead of covering it: pad Grafana's panel area by the sidebars' widths and
  // put the sidebars in the padding. The panels reflow to the narrower width.
  const SESSIONS_WIDTH = 260, COLLAPSED_WIDTH = 36, DETAILS_WIDTH = 440;
  const panelArea = () => document.querySelector('[data-testid$="DashboardSidebarSplitter body container"]');
  const layout = () => {
    const area = panelArea();
    if (!area) return;
    if (!area.dataset.basePadding) {
      const cs = getComputedStyle(area);
      area.dataset.basePadding = `${parseFloat(cs.paddingLeft)},${parseFloat(cs.paddingRight)}`;
    }
    const [baseLeft, baseRight] = area.dataset.basePadding.split(',').map(Number);
    const left = sessionsBar.dataset.collapsed === 'true' ? COLLAPSED_WIDTH : SESSIONS_WIDTH;
    const right = drawer.dataset.key ? DETAILS_WIDTH : 0;
    area.style.paddingLeft = `${baseLeft + left}px`;
    area.style.paddingRight = `${baseRight + right}px`;
    const r = area.getBoundingClientRect();
    const innerRight = r.left + area.clientLeft + area.clientWidth; // left of the scrollbar
    const box = { top: `${r.top}px`, height: `${r.height}px` };
    Object.assign(sessionsBar.style, box, { left: `${r.left}px`, width: `${left}px`, display: 'flex' });
    Object.assign(drawer.style, box, { left: `${innerRight - right}px`, width: `${right}px`, display: right ? 'flex' : 'none' });
  };
  state.resizeObserver?.disconnect();
  state.resizeObserver = new ResizeObserver(layout);
  if (panelArea()) state.resizeObserver.observe(panelArea());

  const el = (tag, style, text) => {
    const node = document.createElement(tag);
    Object.assign(node.style, style || {});
    if (text !== undefined) node.textContent = String(text);
    return node;
  };
  const muted = { color: theme.colors.text.secondary };
  const headingStyle = { fontSize: '12px', fontWeight: '500', textTransform: 'uppercase', letterSpacing: '0.04em', ...muted };
  const plainButtonStyle = { background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' };
  const section = (title) => {
    const box = el('section', { padding: '12px 16px', borderTop: `1px solid ${theme.colors.border.weak}` });
    box.appendChild(el('h4', { ...headingStyle, margin: '0 0 8px' }, title));
    return box;
  };
  const keyValues = (pairs) => {
    const grid = el('div', { display: 'grid', gridTemplateColumns: 'minmax(110px, 40%) 1fr', gap: '4px 12px' });
    pairs.forEach(([k, v]) => {
      grid.appendChild(el('div', { ...muted, fontFamily: theme.typography.fontFamilyMonospace, fontSize: '12px', wordBreak: 'break-all' }, k));
      grid.appendChild(el('div', { wordBreak: 'break-word', whiteSpace: 'pre-wrap' }, v === '' ? '""' : v));
    });
    return grid;
  };
  const sorted = (pairs) => [...pairs].sort(([a], [b]) => a.localeCompare(b));
  const explore = (pane) => '/explore?schemaVersion=1&panes=' + encodeURIComponent(JSON.stringify({ a: pane }));

  const close = () => locationService.partial({ 'var-trace': '', 'var-span': '', 'var-event': '' });
  // raw is the record as Tempo or Loki returned it, shown instead of the sections in JSON view.
  const headerButton = (text, title, onclick) => {
    const button = el('button', { ...plainButtonStyle, lineHeight: '1', padding: '0 2px' }, text);
    button.title = title;
    button.onclick = onclick;
    return button;
  };
  const render = (title, subtitle, sections, link, raw) => {
    drawer.replaceChildren();
    const header = el('header', { display: 'flex', alignItems: 'flex-start', gap: '8px', padding: '16px' });
    const heading = el('div', { flex: '1', minWidth: '0' });
    heading.appendChild(el('div', { fontSize: '16px', fontWeight: '500', wordBreak: 'break-word' }, title));
    heading.appendChild(el('div', { ...muted, marginTop: '4px' }, subtitle));
    const closeButton = headerButton('✕', 'Close (Esc)', close);
    closeButton.style.fontSize = '18px';
    header.appendChild(heading);
    const body = el('div', { flex: '1', overflowY: 'auto' });
    if (raw) {
      const showRaw = readFlag(DETAILS_JSON_KEY);
      const toggle = headerButton(showRaw ? 'Fields' : 'JSON', showRaw ? 'Show fields' : 'Show the raw record as JSON', () => {
        writeFlag(DETAILS_JSON_KEY, !showRaw);
        render(title, subtitle, sections, link, raw);
      });
      Object.assign(toggle.style, { fontSize: '12px', border: `1px solid ${theme.colors.border.medium}`, borderRadius: '2px', padding: '2px 6px' });
      header.appendChild(toggle);
      if (showRaw) {
        const json = JSON.stringify(raw, null, 2);
        const copy = headerButton('Copy', 'Copy the JSON', async () => {
          await navigator.clipboard.writeText(json);
          copy.textContent = 'Copied';
        });
        Object.assign(copy.style, { ...muted, fontSize: '12px' });
        const toolbar = el('div', { display: 'flex', justifyContent: 'flex-end', padding: '8px 16px 0' });
        toolbar.appendChild(copy);
        body.append(toolbar, el('pre', {
          margin: '0', padding: '4px 16px 16px', fontFamily: theme.typography.fontFamilyMonospace, fontSize: '12px',
          whiteSpace: 'pre-wrap', wordBreak: 'break-word',
        }, json));
      } else {
        body.append(...sections);
      }
    } else {
      body.append(...sections);
    }
    header.appendChild(closeButton);
    drawer.append(header, body);
    if (link) {
      const footer = el('footer', { padding: '12px 16px', borderTop: `1px solid ${theme.colors.border.weak}` });
      const a = el('a', { color: theme.colors.text.link }, link.text);
      a.href = link.href;
      a.target = '_blank';
      footer.appendChild(a);
      drawer.appendChild(footer);
    }
  };

  const timeRange = context.panel.data.timeRange;
  const query = async (q, from = timeRange.from.valueOf(), to = timeRange.to.valueOf()) => {
    const res = await fetch('/api/ds/query', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: String(from), to: String(to), queries: [{ refId: 'A', ...q }] }),
    });
    const result = (await res.json()).results?.A;
    if (!result || result.error) throw new Error(result?.error || `HTTP ${res.status}`);
    // Turn the first frame into one object per row.
    const frame = result.frames?.[0];
    if (!frame) return [];
    const names = frame.schema.fields.map((f) => f.name);
    return (frame.data.values[0] || []).map((_, i) => Object.fromEntries(names.map((n, j) => [n, frame.data.values[j][i]])));
  };

  const statusText = { 0: 'Unset', 1: 'OK', 2: 'Error' };
  const showSpan = async (traceId, spanId, show) => {
    const span = (await query({ datasource: { type: 'tempo', uid: 'tempo' }, queryType: 'traceId', query: traceId }))
      .find((s) => s.spanID === spanId);
    if (!span) return show('Span not found', `${spanId} isn't in the selected time range.`, []);
    const overview = section('Span');
    overview.appendChild(keyValues([
      ['kind', span.kind], ['status', statusText[span.statusCode] + (span.statusMessage ? `: ${span.statusMessage}` : '')],
      ['scope', span.instrumentationLibraryName], ['service', span.serviceName],
      ['trace ID', span.traceID], ['span ID', span.spanID], ['parent span ID', span.parentSpanID || '(root)'],
    ]));
    const attributes = section('Attributes');
    attributes.appendChild((span.tags || []).length ? keyValues(sorted(span.tags.map((t) => [t.key, t.value]))) : el('div', muted, 'None'));
    const sections = [overview, attributes];
    if ((span.logs || []).length) {
      const events = section(`Span events (${span.logs.length})`);
      span.logs.forEach((e) => {
        events.appendChild(el('div', { marginTop: '8px' }, `${e.name || 'unnamed'}  +${fmtDur(e.timestamp - span.startTime)}`));
        if ((e.fields || []).length) events.appendChild(keyValues(sorted(e.fields.map((f) => [f.key, f.value]))));
      });
      sections.push(events);
    }
    const resource = section('Resource');
    resource.appendChild(keyValues(sorted((span.serviceTags || []).map((t) => [t.key, t.value]))));
    sections.push(resource);
    show(span.operationName, `span · ${fmtTime(span.startTime)} · ${fmtDur(span.duration)}`, sections, {
      text: 'Open trace in Explore ↗',
      href: explore({
        datasource: 'tempo', queries: [{ refId: 'A', datasource: { type: 'tempo', uid: 'tempo' }, queryType: 'traceql', query: traceId }],
        range: { from: String(timeRange.from.valueOf()), to: String(timeRange.to.valueOf()) }, panelsState: { trace: { spanId } },
      }),
    }, span);
  };

  // The Timeline's own log query, so Loki's row ids (a hash of labels and line) match.
  const logsExpr = replaceVariables(context.panel.data.request.targets.find((t) => t.refId === 'B').expr);
  const showLog = async (id, show) => {
    // Loki's row id starts with the record's timestamp in nanoseconds, so ask for that moment only;
    // searching the whole time range returns at most maxLines records and can miss it.
    const ms = Number(id.split('_')[0]) / 1e6;
    const around = Number.isFinite(ms) ? [Math.floor(ms) - 1, Math.ceil(ms) + 1] : [];
    const record = (await query({ datasource: { type: 'loki', uid: 'loki' }, queryType: 'range', maxLines: 1000, expr: logsExpr }, ...around))
      .find((r) => r.id === id);
    if (!record) return show('Log record not found', "It isn't in the selected time range.", []);
    const labels = record.labels || {};
    const body = section('Body');
    body.appendChild(el('div', { whiteSpace: 'pre-wrap', wordBreak: 'break-word', fontFamily: theme.typography.fontFamilyMonospace }, record.Line || '(empty)'));
    const attributes = section('Attributes');
    attributes.appendChild(keyValues(sorted(Object.entries(labels))));
    const t = record.Time;
    show(labels.event_name || 'unnamed', `log · ${fmtTime(t)} · ${labels.scope_name || ''}`, [body, attributes], {
      text: 'Open in Explore ↗',
      href: explore({
        datasource: 'loki', queries: [{ refId: 'A', datasource: { type: 'loki', uid: 'loki' }, expr: logsExpr }],
        range: { from: String(t - 60000), to: String(t + 60000) },
      }),
    }, record);
  };

  // Sessions sidebar: every session in the time range, from its own queries without the session
  // filter, so picking one doesn't shrink the list.
  const service = replaceVariables('$service');
  const selectedSessions = () => {
    const v = locationService.getSearchObject()['var-session'];
    const values = (Array.isArray(v) ? v : [v]).filter(Boolean);
    return values.length === 0 || values.includes('$__all') ? [] : values;
  };
  const fmtLength = (ms) => {
    const s = Math.round(ms / 1000);
    return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor(s / 60) % 60}m`;
  };
  const fmtStart = (t) => {
    const d = new Date(t);
    const time = d.toLocaleTimeString([], { hour12: false });
    return d.toDateString() === new Date().toDateString() ? time : `${d.toLocaleDateString([], { month: 'short', day: 'numeric' })} ${time}`;
  };
  const setCollapsed = (collapsed) => {
    sessionsBar.dataset.collapsed = collapsed;
    writeFlag(SESSIONS_COLLAPSED_KEY, collapsed);
    renderSessions(true);
    layout();
  };
  const renderSessions = (force) => {
    const sessions = state.sessions || [];
    const chosen = selectedSessions();
    const signature = JSON.stringify([sessions, state.sessionsTruncated, chosen, sessionsBar.dataset.collapsed, theme.isDark]);
    if (!force && signature === sessionsBar.dataset.signature) return;
    sessionsBar.dataset.signature = signature;
    sessionsBar.replaceChildren();
    const toggle = el('button', { ...plainButtonStyle, fontSize: '16px', padding: '4px 8px' });
    if (sessionsBar.dataset.collapsed === 'true') {
      toggle.textContent = '»';
      toggle.title = 'Show sessions';
      toggle.onclick = () => setCollapsed(false);
      sessionsBar.appendChild(toggle);
      return;
    }
    toggle.textContent = '«';
    toggle.title = 'Hide sessions';
    toggle.onclick = () => setCollapsed(true);
    const header = el('header', { display: 'flex', alignItems: 'center', padding: '12px 8px 8px 16px' });
    const heading = el('h4', { ...headingStyle, flex: '1', margin: '0' }, `Sessions (${sessions.length})`);
    header.append(heading, toggle);
    const list = el('div', { flex: '1', overflowY: 'auto' });
    if (state.sessionsTruncated) {
      list.appendChild(el('div', { ...muted, fontSize: '12px', padding: '0 16px 8px' }, 'Too much data in this time range: some sessions or counts may be missing.'));
    }
    const item = (selected, onclick, lines, title) => {
      const row = el('div', {
        padding: '8px 16px 8px 13px', cursor: 'pointer', borderLeft: `3px solid ${selected ? theme.colors.primary.main : 'transparent'}`,
        background: selected ? theme.colors.action.selected : 'transparent',
      });
      row.onmouseenter = () => { if (!selected) row.style.background = theme.colors.action.hover; };
      row.onmouseleave = () => { if (!selected) row.style.background = 'transparent'; };
      row.onclick = onclick;
      if (title) row.title = title;
      row.append(...lines);
      list.appendChild(row);
    };
    item(chosen.length === 0, () => locationService.partial({ 'var-session': '$__all' }), [el('div', {}, 'All sessions')]);
    sessions.forEach((s) => {
      const name = el('div', { display: 'flex', alignItems: 'center', gap: '8px', fontFamily: theme.typography.fontFamilyMonospace });
      name.append(el('span', {}, s.id.slice(0, 8)));
      if (s.crash) name.append(el('span', { color: theme.colors.error.text, fontFamily: theme.typography.fontFamily, fontSize: '11px' }, 'crash'));
      item(chosen.includes(s.id), () => locationService.partial({ 'var-session': s.id }), [
        name,
        el('div', { ...muted, fontSize: '12px' }, `${fmtStart(s.start)} · ${fmtLength(s.end - s.start)}`),
        el('div', { ...muted, fontSize: '12px' }, `${s.spans} spans · ${s.logs} logs`),
      ], s.id);
    });
    if (sessions.length === 0) list.appendChild(el('div', { ...muted, padding: '8px 16px' }, 'No sessions in this time range'));
    sessionsBar.append(header, list);
  };
  const SESSION_TRACES = 1000, SESSION_SPANS_PER_TRACE = 100, SESSION_LOGS = 5000;
  const loadSessions = async () => {
    // No service means no telemetry in the time range; Loki rejects a query for an empty one.
    if (!service) {
      state.sessions = [];
      state.sessionsTruncated = false;
      renderSessions();
      return;
    }
    const [spans, logs] = await Promise.all([
      query({ datasource: { type: 'tempo', uid: 'tempo' }, queryType: 'traceql', tableType: 'spans', limit: SESSION_TRACES, spss: SESSION_SPANS_PER_TRACE,
        query: `{resource.service.name=${JSON.stringify(service)} && span.session.id != nil} | select(span.session.id)` }),
      query({ datasource: { type: 'loki', uid: 'loki' }, queryType: 'range', maxLines: SESSION_LOGS,
        expr: `{service_name=${JSON.stringify(service)}} | session_id != ""` }),
    ]);
    const byId = new Map();
    const add = (id, start, end, kind, crash) => {
      if (!id) return;
      const s = byId.get(id) || { id, start, end, spans: 0, logs: 0, crash: false };
      s.start = Math.min(s.start, start);
      s.end = Math.max(s.end, end);
      s[kind] += 1;
      s.crash = s.crash || crash;
      byId.set(id, s);
    };
    spans.forEach((s) => add(s['session.id'], s.time, s.time + s.duration / 1e6, 'spans', false));
    logs.forEach((l) => {
      const labels = l.labels || {};
      const isCrash = labels.event_name === 'device.crash' || labels.scope_name === 'io.opentelemetry.kscrash';
      add(labels.session_id, l.Time, l.Time, 'logs', isCrash);
    });
    state.sessions = [...byId.values()].sort((a, b) => b.start - a.start);
    // The queries return at most SESSION_TRACES traces, SESSION_SPANS_PER_TRACE spans per trace
    // and SESSION_LOGS log records.
    const spansPerTrace = {};
    spans.forEach((s) => { spansPerTrace[s.traceIdHidden] = (spansPerTrace[s.traceIdHidden] || 0) + 1; });
    state.sessionsTruncated = Object.keys(spansPerTrace).length >= SESSION_TRACES || logs.length >= SESSION_LOGS
      || Object.values(spansPerTrace).some((n) => n >= SESSION_SPANS_PER_TRACE);
    renderSessions();
  };

  // Mark the selected row in the Events table. Grafana's table can't style a row from a variable
  // and re-renders rows as they scroll, so re-mark whenever the panels' DOM changes. Its rows are
  // display: contents, so the cells carry the highlight.
  const markEventsRow = () => {
    const q = locationService.getSearchObject();
    document.querySelectorAll('[role=row] a[href*="var-event="]').forEach((a) => {
      const link = new URLSearchParams(a.getAttribute('href').split('?')[1]);
      const isSelected = q['var-span']
        ? link.get('var-span') === q['var-span'] && link.get('var-trace') === q['var-trace']
        : !!q['var-event'] && link.get('var-event') === q['var-event'];
      a.closest('[role=row]').querySelectorAll('[role=gridcell]').forEach((cell, i) => {
        cell.style.background = isSelected ? theme.colors.action.selected : '';
        cell.style.boxShadow = isSelected && i === 0 ? `inset 3px 0 ${theme.colors.primary.main}` : '';
      });
    });
  };
  state.rowObserver?.disconnect();
  state.rowObserver = new MutationObserver(() => requestAnimationFrame(markEventsRow));
  if (panelArea()) state.rowObserver.observe(panelArea(), { childList: true, subtree: true });

  // Open, switch or close the drawer to match the URL. Content is fetched once per selection.
  const showSelection = () => {
    // Left the dashboard: hide the sidebars and stop listening.
    if (chart.isDisposed()) {
      drawer.style.display = sessionsBar.style.display = 'none';
      drawer.dataset.key = '';
      state.unlisten?.();
      state.resizeObserver?.disconnect();
      state.rowObserver?.disconnect();
      return;
    }
    renderSessions();
    markEventsRow();
    const q = locationService.getSearchObject();
    const key = selectionKey();
    if (key !== selected) {
      selected = key;
      chart.setOption({ series: series.map((s) => ({ name: s.name, data: s.data })) });
    }
    if (key === drawer.dataset.key) return;
    drawer.dataset.key = key;
    layout();
    if (!key) return;
    render('Loading…', '', []);
    // A slower response for an earlier selection mustn't replace this one's details.
    const show = (...args) => drawer.dataset.key === key && render(...args);
    const load = q['var-span'] ? showSpan(q['var-trace'], q['var-span'], show) : showLog(q['var-event'], show);
    load.catch((e) => show('Could not load details', e.message, []));
  };

  // This code reruns on every refresh, so replace the handlers instead of adding more.
  const chart = context.panel.chart;
  chart.off('click');
  chart.on('click', (p) => {
    const r = rows[p.value[0]];
    // Clicking the selected item again closes the drawer.
    if (keyOf(r) === selected) return close();
    locationService.partial(r.isSpan
      ? { 'var-trace': r.traceId, 'var-span': r.key, 'var-event': '' }
      : { 'var-trace': '', 'var-span': '', 'var-event': r.key });
  });
  state.unlisten?.();
  state.unlisten = locationService.getHistory().listen(showSelection);
  if (state.onKey) document.removeEventListener('keydown', state.onKey);
  state.onKey = (e) => { if (e.key === 'Escape' && drawer.dataset.key) close(); };
  document.addEventListener('keydown', state.onKey);
  showSelection();
  layout();
  loadSessions().catch((e) => {
    sessionsBar.replaceChildren(el('div', { ...muted, padding: '12px 16px' }, `Could not load sessions: ${e.message}`));
  });

  // Fit the time axis to the data rather than the whole time range, where sessions of a few
  // minutes would be slivers.
  const first = Math.min(...rows.map((r) => r.start)), last = Math.max(...rows.map((r) => r.end));
  const pad = Math.max((last - first) * 0.03, 1000);
  if (rows.length === 0) {
    return {
      title: {
        text: 'No telemetry in this time range',
        subtext: 'Run HackerNewsDemo in the simulator, or pick a longer time range.',
        left: 'center',
        top: 'middle',
        itemGap: 8,
        textStyle: { color: theme.colors.text.primary, fontSize: 16, fontWeight: 500 },
        subtextStyle: { color: theme.colors.text.secondary, fontSize: 13 },
      },
    };
  }
  return {
    backgroundColor: 'transparent',
    animation: false,
    legend: { top: 0, textStyle: { color: theme.colors.text.secondary } },
    tooltip: {
      trigger: 'item',
      formatter: (p) => {
        const r = rows[p.value[0]];
        const when = r.end > r.start ? `${fmtTime(r.start)} → ${fmtTime(r.end)} (${fmtDur(r.end - r.start)})` : fmtTime(r.start);
        return `<b>${esc(r.text)}</b><br/>${esc(r.scope)}<br/>${when}<br/>session ${esc(r.session)}<br/><i>Click for details</i>`;
      },
    },
    grid: { left: 110, right: 20, top: 30, bottom: 50 },
    xAxis: {
      type: 'time', min: first - pad, max: last + pad,
      axisLabel: { color: theme.colors.text.secondary }, splitLine: { show: true, lineStyle: { color: theme.colors.border.weak } },
    },
    yAxis: {
      type: 'category', data: lanes, inverse: true,
      axisLabel: { color: theme.colors.text.secondary, formatter: (s) => s.slice(0, 8) },
      splitLine: { show: true, lineStyle: { color: theme.colors.border.weak } },
    },
    dataZoom: [{ type: 'inside', xAxisIndex: 0, filterMode: 'weakFilter' }, { type: 'slider', xAxisIndex: 0, height: 18, bottom: 8, filterMode: 'weakFilter' }],
    series,
  };
};
