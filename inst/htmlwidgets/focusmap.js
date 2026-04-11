HTMLWidgets.widget({

  name: "focusmap",
  type: "output",

  factory: function (el, width, height) {

    /* ── scoped state ──────────────────────────────────────── */
    var features, projection, geoPath, opts = {};
    var svgEl, cameraLayer, baseLayer, socketFill, socketOutline, toastLayer;
    var focusCardEl;
    var zoomBehaviour, tooltipEl;
    var groupColorScale = null;
    var lastTargetFeature = null;
    var tooltipFrame = null;
    var tooltipEvent = null;

    var S = {
      mode: "idle",
      selectedFeature: null,
      pendingFeature: null,
      currentTransform: d3.zoomIdentity,
      scrollOutCount: 0,
      scrollOutTimer: null
    };

    /* ── util ──────────────────────────────────────────────── */
    function clamp(x, lo, hi) { return Math.max(lo, Math.min(hi, x)); }

    function setShinyInput(id, value) {
      if (!window.Shiny) return;
      if (typeof Shiny.setInputValue === "function") {
        Shiny.setInputValue(id, value, { priority: "event" });
      } else if (typeof Shiny.onInputChange === "function") {
        Shiny.onInputChange(id, value);
      }
    }

    // All values come from opts (set by R via the payload).
    // When show_sidebar is TRUE the widget builds its own controls;
    // when FALSE the host app (Shiny) owns them and passes values
    // through opts on each render.
    function liftScale() { return opts.liftScale || 1.16; }
    function focusPadding() { return Math.max(0, opts.focusPadding == null ? 40 : +opts.focusPadding); }
    function focusSize() { return clamp(opts.focusSize == null ? 0.76 : +opts.focusSize, 0.25, 1.35); }
    function infoCardScale() { return clamp(opts.infoCardScale == null ? 1 : +opts.infoCardScale, 0.75, 1.6); }
    function maxZoom(fromHome) {
      if (opts.maxZoom != null && isFinite(+opts.maxZoom) && +opts.maxZoom > 0) return +opts.maxZoom;
      if (fromHome && opts.performanceMode) return 18;
      if (opts.performanceMode) return 20;
      return 18;
    }
    function fontSize()  { return opts.fontSize  || 14; }
    function showLabels() { return opts.showLabels !== false; }
    function areaMin()   { return opts.areaMin   || 5000; }
    function widthMin()  { return opts.widthMin  || 95; }
    function heightMin() { return opts.heightMin || 28; }

    /* ── DOM scaffolding ───────────────────────────────────── */
    function buildDOM() {
      el.innerHTML = "";

      el.style.display   = "flex";
      el.style.overflow   = "hidden";
      el.style.fontFamily = "'DM Sans',system-ui,sans-serif";
      el.style.background = "#f6f8fb";
      el.style.position   = "relative";
      el.style.width      = el.style.width  || "100%";
      el.style.height     = el.style.height || "100%";
      el.style.minWidth   = "0";
      el.style.minHeight  = "0";

      var wrap = document.createElement("div");
      wrap.className = "fm-map-wrap";
      el.appendChild(wrap);

      svgEl = d3.select(wrap).append("svg")
        .attr("class", "fm-svg")
        .attr("preserveAspectRatio", "xMidYMid meet");

      var defs = svgEl.append("defs");
      var blur = defs.append("filter").attr("id", "fm-shadow-blur")
        .attr("x", "-40%").attr("y", "-40%").attr("width", "180%").attr("height", "180%");
      blur.append("feGaussianBlur").attr("stdDeviation", "5.5");

      cameraLayer  = svgEl.append("g").attr("id", "fm-camera");
      cameraLayer
        .style("transform-origin", "0 0")
        .style("transform-box", "view-box");
      baseLayer    = cameraLayer.append("g").attr("id", "fm-base");
      var sg       = cameraLayer.append("g");
      socketFill   = sg.append("path").attr("id", "fm-sfill")
        .attr("fill", "#eef5fb").attr("stroke", "#cadeee")
        .attr("stroke-width", "1").style("vector-effect", "non-scaling-stroke")
        .style("display", "none");
      socketOutline = sg.append("path").attr("id", "fm-sout")
        .attr("fill", "none").attr("stroke", "#7fa3c4").attr("stroke-opacity", ".55")
        .attr("stroke-width", ".9").style("vector-effect", "non-scaling-stroke")
        .style("display", "none");
      toastLayer   = cameraLayer.append("g").attr("id", "fm-toast");

      // Tooltip
      tooltipEl = document.createElement("div");
      tooltipEl.className = "fm-tooltip";
      wrap.appendChild(tooltipEl);

      focusCardEl = document.createElement("div");
      focusCardEl.className = "fm-focus-card fm-card-top-right";
      focusCardEl.style.display = "none";
      wrap.appendChild(focusCardEl);

      // Right-click to dismiss — robust cross-browser/iframe handling
      var rightClickHandler = function (e) {
        if (S.mode !== "focused") return;
        e.preventDefault();
        e.stopPropagation();
        clearFocus();
      };

      wrap.addEventListener("contextmenu", rightClickHandler, true);
      wrap.addEventListener("pointerup", function (e) {
        if (e.button === 2) rightClickHandler(e);
      }, true);
      wrap.addEventListener("mouseup", function (e) {
        if (e.button === 2) rightClickHandler(e);
      }, true);

      // Zoom — programmatic only, no scroll/drag
      zoomBehaviour = d3.zoom().scaleExtent([1, 50])
        .on("zoom", function (e) {
          applyCameraTransform(e.transform);
          S.currentTransform = e.transform;
        });

      svgEl.call(zoomBehaviour)
        .on("wheel.zoom", null).on("mousedown.zoom", null)
        .on("touchstart.zoom", null).on("dblclick.zoom", null);

      // Scroll-out to dismiss: 3 consecutive zoom-out wheel ticks
      svgEl.node().addEventListener("wheel", function (e) {
        if (S.mode !== "focused") { S.scrollOutCount = 0; return; }
        e.preventDefault();

        if (e.deltaY > 0) {
          S.scrollOutCount++;
          clearTimeout(S.scrollOutTimer);
          S.scrollOutTimer = setTimeout(function () { S.scrollOutCount = 0; }, 700);

          if (S.scrollOutCount >= 3) {
            S.scrollOutCount = 0;
            clearTimeout(S.scrollOutTimer);
            clearFocus();
          }
        } else if (e.deltaY < 0) {
          S.scrollOutCount = 0;
          clearTimeout(S.scrollOutTimer);
        }
      }, { passive: false });

      // Keyboard — managed in renderValue to avoid stacking
      injectCSS();
    }

    function onKey(e) {
      if (e.key === "Escape" && el.contains(document.activeElement || document.body)) {
        clearFocus();
      }
    }

    /* ── CSS injection (once per page) ─────────────────────── */
    var cssId = "__fm_css";

    function injectCSS() {
      if (document.getElementById(cssId)) return;

      var s = document.createElement("style");
      s.id = cssId;
      s.textContent = [
        ".fm-map-wrap{flex:1;position:relative;overflow:hidden;padding:8px}",
        ".fm-svg{width:100%;height:100%;display:block;border-radius:14px;background:linear-gradient(180deg,#e7eef5,#dde7f1);box-shadow:0 8px 24px rgba(15,35,60,.08)}",
        "#fm-camera{will-change:transform}",
        ".fm-county{cursor:pointer;stroke-linejoin:round;stroke-linecap:round}",
        ".fm-county:hover,.fm-county.is-target{fill-opacity:.72!important;stroke:#16385c;stroke-width:1.1px;transition:fill-opacity 100ms ease}",
        ".fm-performance-mode .fm-county:hover{fill-opacity:.64!important;stroke:#fff!important;stroke-width:.8px!important;transition:none!important}",
        ".fm-performance-mode .fm-county.is-target{fill-opacity:.72!important;stroke:#16385c;stroke-width:1px!important;transition:none!important}",
        "#fm-base.fm-has-focus .fm-county{fill-opacity:.3!important;pointer-events:auto}",
        "#fm-base.fm-has-focus .fm-county.hidden-src{opacity:0;pointer-events:none}",
        ".fm-county.hidden-src{opacity:0;pointer-events:none}",
        ".fm-toast-clone{stroke:#284f76;stroke-width:1.7px;vector-effect:non-scaling-stroke;stroke-linejoin:round;stroke-linecap:round}",
        ".fm-toast-shadow{fill:#10233a;opacity:.12}",
        ".fm-focus-label{font-family:'DM Sans',system-ui,sans-serif;font-weight:700;fill:#10233a;paint-order:stroke;stroke:#fff;stroke-width:2.2px;stroke-linejoin:round;letter-spacing:-.01em}",
        "@keyframes fm-rise{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}",
        ".fm-toast-g{pointer-events:none;animation:fm-rise 180ms cubic-bezier(.22,1,.36,1)}",
        ".fm-tooltip{position:absolute;pointer-events:none;background:rgba(26,26,46,.88);color:#fff;font-size:12px;font-weight:500;padding:4px 10px;border-radius:6px;white-space:nowrap;opacity:0;transition:opacity 80ms;z-index:20;font-family:'DM Sans',system-ui,sans-serif}",
        ".fm-focus-card{--fm-card-scale:1;position:absolute;z-index:25;max-width:min(calc(320px * var(--fm-card-scale)),calc(100% - 28px));background:rgba(255,255,255,.94);color:#10233a;border:1px solid #d7e3ef;border-radius:8px;box-shadow:0 14px 34px rgba(15,35,60,.16);padding:calc(12px * var(--fm-card-scale)) calc(14px * var(--fm-card-scale));font-family:'DM Sans',system-ui,sans-serif;backdrop-filter:blur(8px);pointer-events:auto}",
        ".fm-card-top-right{top:14px;right:14px}.fm-card-top-left{top:14px;left:14px}.fm-card-bottom-right{right:14px;bottom:14px}.fm-card-bottom-left{left:14px;bottom:14px}",
        ".fm-card-title{font-size:calc(15px * var(--fm-card-scale));font-weight:800;line-height:1.2;margin:0 calc(20px * var(--fm-card-scale)) calc(8px * var(--fm-card-scale)) 0;color:#10233a}",
        ".fm-card-close{position:absolute;top:7px;right:8px;border:0;background:transparent;color:#5c7188;font-size:calc(18px * var(--fm-card-scale));line-height:1;cursor:pointer;padding:2px 4px}",
        ".fm-card-row{display:grid;grid-template-columns:minmax(calc(72px * var(--fm-card-scale)),.8fr) minmax(0,1.2fr);gap:calc(8px * var(--fm-card-scale));font-size:calc(12px * var(--fm-card-scale));line-height:1.35;padding:calc(4px * var(--fm-card-scale)) 0;border-top:1px solid #edf2f7}",
        ".fm-card-key{color:#60758c;font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.fm-card-val{color:#16324f;font-weight:600;overflow-wrap:anywhere}",
        ".fm-is-flying .fm-county{stroke:none!important;vector-effect:none!important;shape-rendering:optimizeSpeed;pointer-events:none}",
        ".fm-is-flying .fm-county:hover,.fm-is-flying .fm-county.is-target{stroke:none!important}",
        ".fm-is-flying .fm-toast-g{display:none}"
      ].join("\n");

      document.head.appendChild(s);
    }

    /* ── projection + render ───────────────────────────────── */
    function fitProjection() {
      var r = svgEl.node().getBoundingClientRect();
      var w = Math.max(1, r.width  || width  || 800);
      var h = Math.max(1, r.height || height || 600);

      svgEl.attr("viewBox", "0 0 " + w + " " + h);

      var fc = { type: "FeatureCollection", features: features };
      projection = d3.geoMercator().fitExtent([[10, 10], [w - 10, h - 10]], fc);

      // 2-decimal precision (0.01px) — imperceptible rounding, ~15% shorter
      // path strings vs default 6-decimal. Keeps shared county borders
      // aligned. digits(0) and digits(1) cause visible jagged edges.
      geoPath = d3.geoPath(projection).digits(2);

      features.forEach(function (f) {
        var b = geoPath.bounds(f), c = geoPath.centroid(f);
        var gw = Math.max(b[1][0] - b[0][0], 0.5);
        var gh = Math.max(b[1][1] - b[0][1], 0.5);
        f._s = {
          x0: b[0][0], y0: b[0][1], x1: b[1][0], y1: b[1][1],
          w: gw, h: gh,
          ax: isFinite(c[0]) ? c[0] : (b[0][0] + b[1][0]) / 2,
          ay: isFinite(c[1]) ? c[1] : (b[0][1] + b[1][1]) / 2,
          // Cache the path d string — avoids recomputing on toast/socket
          pathD: geoPath(f) || ""
        };
      });
    }

    function buildColorScale() {
      if (!opts.hasGroups) { groupColorScale = null; return; }
      var groups = [];
      features.forEach(function (f) {
        var g = f.properties.group;
        if (g && groups.indexOf(g) < 0) groups.push(g);
      });
      groups.sort();
      var palette = [
        "#2d6ea3", "#c95438", "#3a8a6e", "#7b62b8",
        "#c4872e", "#5b8ec9", "#d46b8a", "#4a9e8f",
        "#8b7355", "#6c8e3e", "#b05f9e", "#cb9946"
      ];
      var map = {};
      groups.forEach(function (g, i) { map[g] = palette[i % palette.length]; });
      groupColorScale = function (g) { return map[g] || opts.fill || "#2d6ea3"; };
    }

    function featureFill(f) {
      if (groupColorScale && f.properties.group) {
        return groupColorScale(f.properties.group);
      }
      return opts.fill || "#2d6ea3";
    }

    function renderPaths() {
      baseLayer.selectAll(".fm-county")
        .data(features, function (d) { return d.properties.feature_id; })
        .join(
          function (enter) {
            return enter.append("path")
              .attr("class", "fm-county")
              .attr("id", function (d) { return "fm-b-" + d.properties.feature_id; })
              .attr("d", function (d) { return d._s.pathD; })
              .attr("fill", featureFill)
              .attr("fill-opacity", opts.fillOpacity || 0.58)
              .attr("stroke", opts.stroke || "#fff")
              .attr("stroke-width", "0.8px")
              .style("vector-effect", "non-scaling-stroke")
              .on("click", function (e, d) { onCountyClick(d); })
              .on("mouseenter", function (e, d) { showTooltip(e, d); })
              .on("mousemove",  function (e)    { moveTooltip(e); })
              .on("mouseleave", function ()     { hideTooltip(); })
              .each(function (d) { d._node = this; });
          },
          function (update) {
            return update
              .attr("d", function (d) { return d._s.pathD; })
              .attr("fill", featureFill)
              .each(function (d) { d._node = this; });
          },
          function (exit) { return exit.remove(); }
        );
    }

    function applyCameraTransform(t) {
      if (opts.performanceMode) {
        cameraLayer
          .attr("transform", null)
          .style("transform", "translate(" + t.x + "px," + t.y + "px) scale(" + t.k + ")");
      } else {
        cameraLayer
          .style("transform", null)
          .attr("transform", t);
      }
    }

    /* ── tooltip ───────────────────────────────────────────── */
    function showTooltip(e, d) {
      if (S.mode === "focused") return;
      tooltipEl.textContent = d.properties.NAME || d.properties.feature_id;
      tooltipEl.style.opacity = "1";
      moveTooltip(e);
    }
    function moveTooltip(e) {
      tooltipEvent = e;
      if (tooltipFrame) return;
      tooltipFrame = requestAnimationFrame(function () {
        tooltipFrame = null;
        if (!tooltipEvent) return;
        var r = el.querySelector(".fm-map-wrap").getBoundingClientRect();
        tooltipEl.style.left = (tooltipEvent.clientX - r.left + 12) + "px";
        tooltipEl.style.top  = (tooltipEvent.clientY - r.top  - 28) + "px";
      });
    }
    function hideTooltip() {
      tooltipEl.style.opacity = "0";
      tooltipEvent = null;
    }

    function escapeHTML(value) {
      return String(value == null ? "" : value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
    }

    function labelFromColumn(col) {
      if (opts.infoLabels && opts.infoLabels[col]) return opts.infoLabels[col];
      return String(col || "")
        .replace(/^info_/, "")
        .replace(/_/g, " ")
        .replace(/\b\w/g, function (m) { return m.toUpperCase(); });
    }

    function showFocusCard(f) {
      if (!focusCardEl || !opts.showInfoCard) return;

      var position = opts.infoPosition || "top-right";
      focusCardEl.className = "fm-focus-card fm-card-" + position;
      focusCardEl.style.setProperty("--fm-card-scale", infoCardScale());

      var props = f.properties || {};
      var title = props.info_title || props.NAME || props.feature_id || "";
      var cols = opts.infoCols || [];
      var keys = opts.infoKeys || cols;
      var rows = cols.map(function (col, i) {
        var key = keys[i] || col;
        var value = props["info_" + key];
        if (value == null || value === "" || value === "NA" || value === "NaN") return "";
        return "<div class=\"fm-card-row\"><div class=\"fm-card-key\">" +
          escapeHTML(labelFromColumn(col)) + "</div><div class=\"fm-card-val\">" +
          escapeHTML(value) + "</div></div>";
      }).join("");

      focusCardEl.innerHTML =
        "<button class=\"fm-card-close\" type=\"button\" aria-label=\"Reset focus\">&times;</button>" +
        "<div class=\"fm-card-title\">" + escapeHTML(title) + "</div>" +
        rows;

      focusCardEl.querySelector(".fm-card-close").addEventListener("click", function (e) {
        e.preventDefault();
        e.stopPropagation();
        clearFocus();
      });

      focusCardEl.style.display = null;
    }

    function hideFocusCard() {
      if (focusCardEl) {
        focusCardEl.style.display = "none";
        focusCardEl.innerHTML = "";
      }
    }

    /* ── label visibility (χ_i) ────────────────────────────── */
    function labelVis(f, camK) {
      var s = f._s, fs = fontSize();
      var fw = s.w * camK, fh = s.h * camK, fa = fw * fh;
      var txt = f.properties.NAME || "";
      var rawW = txt.length * 0.62 * fs;
      var maxW = Math.max(20, fw * 0.85);
      var nl = rawW <= maxW ? 1 : Math.ceil(rawW / maxW);
      var tw = Math.min(rawW, maxW), th = nl * 1.35 * fs;
      var wN = Math.max(widthMin(), 1.15 * tw);
      var hN = Math.max(heightMin(), 1.20 * th);
      var vis = fa >= areaMin() && fw >= wN && fh >= hN;
      var reason = "";
      if (!vis) reason = fa < areaMin() ? "area" : fw < wN ? "width" : "height";
      return { visible: vis, reason: reason, fw: fw, fh: fh, fa: fa, tw: tw, th: th, nl: nl };
    }

    /* ── camera helpers ────────────────────────────────────── */


    function transformFor(f, fromHome) {
      var svgR = svgEl.node().getBoundingClientRect();
      var W = Math.max(1, svgR.width || 800);
      var H = Math.max(1, svgR.height || 600);

      var s  = f._s;
      var dx = Math.max(s.w, 1);
      var dy = Math.max(s.h, 1);
      var ls = liftScale();
      var pad = focusPadding();

      var cx = isFinite(s.ax) ? s.ax : (s.x0 + s.x1) / 2;
      var cy = isFinite(s.ay) ? s.ay : (s.y0 + s.y1) / 2;
      var rise = clamp(Math.max(22, 0.12 * dy + 8), 12, 50);

      // Fit the lifted clone, not just the original path. The clone is scaled
      // around its bbox center and shifted upward by `rise`, so use that final
      // bounds box for camera placement.
      var x0 = cx + (s.x0 - cx) * ls;
      var x1 = cx + (s.x1 - cx) * ls;
      var y0 = cy + (s.y0 - cy) * ls - rise;
      var y1 = cy + (s.y1 - cy) * ls - rise;

      var liftedW = Math.max(x1 - x0, 1);
      var liftedH = Math.max(y1 - y0, 1);
      var bw = liftedW + 2 * pad;
      var bh = liftedH + 2 * pad;
      var fitCx = (x0 + x1) / 2;
      var fitCy = (y0 + y1) / 2;

      var fitScale = Math.min(W / bw, H / bh);
      var sizeScale = Math.min((W * focusSize()) / liftedW, (H * focusSize()) / liftedH);
      var sc = clamp(Math.min(fitScale, sizeScale), 1, maxZoom(fromHome));

      return d3.zoomIdentity
        .translate(W / 2 - sc * fitCx, H / 2 - sc * fitCy)
        .scale(sc);
    }


    /* ── toast + socket ────────────────────────────────────── */
    function showToast(f) {
      toastLayer.selectAll("*").remove();
      var pathD = f._s.pathD, s = f._s;
      var cx = (s.x0 + s.x1) / 2, cy = (s.y0 + s.y1) / 2;
      var ls = liftScale();
      var rise = clamp(Math.max(22, 0.12 * s.h + 8), 12, 50);

      var g = toastLayer.append("g").attr("class", "fm-toast-g");

      // Shadow
      g.append("path").attr("class", "fm-toast-shadow").attr("d", pathD)
        .attr("filter", "url(#fm-shadow-blur)")
        .attr("transform",
          "translate(" + cx + "," + cy + ") scale(" + (ls * .992) +
          ") translate(" + -cx + "," + -cy + ") translate(0," + (rise * .3) + ")");

      // Clone
      g.append("path").attr("class", "fm-toast-clone").attr("d", pathD)
        .attr("fill", featureFill(f))
        .attr("fill-opacity", "0.85")
        .attr("transform",
          "translate(" + cx + "," + cy + ") scale(" + ls +
          ") translate(" + -cx + "," + -cy + ") translate(0," + -rise + ")");

      // Label
      var vis = labelVis(f, S.currentTransform.k);
      if (showLabels() && vis.visible) {
        var labelScale = Math.max((S.currentTransform.k || 1) * ls, 1);
        var labelFontSize = fontSize() / labelScale;
        var labelStrokeWidth = 2.2 / labelScale;
        g.append("text").attr("class", "fm-focus-label")
          .attr("x", s.ax).attr("y", s.ay)
          .attr("text-anchor", "middle").attr("dominant-baseline", "middle")
          .attr("font-size", labelFontSize + "px")
          .style("stroke-width", labelStrokeWidth + "px")
          .attr("transform",
            "translate(" + cx + "," + cy + ") scale(" + ls +
            ") translate(" + -cx + "," + -cy + ") translate(0," + -rise + ")")
          .text(f.properties.NAME);
      }
      return vis;
    }

    function showSocket(f) {
      var d = f._s.pathD;
      socketFill.attr("d", d).style("display", null);
      socketOutline.attr("d", d).style("display", null);
    }
    function hideSocket() {
      socketFill.style("display", "none");
      socketOutline.style("display", "none");
    }
    function clearToast() { toastLayer.selectAll("*").remove(); }

    /* ── interaction FSM ───────────────────────────────────── */
    function setFlightRenderMode(on) {
      cameraLayer.classed("fm-is-flying", !!on);
    }

    function setFeatureClass(f, className, on) {
      if (f && f._node) f._node.classList.toggle(className, !!on);
    }

    function clearTargetFeature() {
      setFeatureClass(lastTargetFeature, "is-target", false);
      lastTargetFeature = null;
    }

    function unhideSelectedFeature() {
      setFeatureClass(S.selectedFeature, "hidden-src", false);
    }

    // Deferred version: waits 2 frames before removing flight mode.
    // This prevents a thundering herd of style recalculations (254 paths
    // simultaneously restoring vector-effect + shape-rendering) from
    // landing in the same frame as the zoom transition's final repaint.
    function endFlightRenderMode() {
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          cameraLayer.classed("fm-is-flying", false);
        });
      });
    }

    function flightDuration(from, to, fromHome) {
      var ds = Math.abs((to.k || 1) - (from.k || 1));
      var dt = Math.hypot((to.x || 0) - (from.x || 0), (to.y || 0) - (from.y || 0));

      var dense = !!opts.performanceMode;
      var base = dense ? (fromHome ? 150 : 120) : (fromHome ? 240 : 200);
      var dur = base + (dense ? 24 : 45) * ds + (dense ? 0.012 : 0.025) * dt;

      if (dense) return clamp(dur, fromHome ? 180 : 140, fromHome ? 320 : 260);
      return clamp(dur, fromHome ? 300 : 200, fromHome ? 560 : 460);
    }

    function flyTo(t, dur) {
      svgEl.interrupt();
      return svgEl.transition()
        .duration(dur || 500)
        .ease(d3.easeCubicInOut)
        .call(zoomBehaviour.transform, t)
        .end();
    }

    async function beginSelection(f) {
      if (S.mode === "flying_to" || S.mode === "flying_home") return;

      var fromHome = (S.mode === "idle");

      S.pendingFeature = f;
      S.mode = "flying_to";
      S.scrollOutCount = 0;
      clearTimeout(S.scrollOutTimer);

      setFlightRenderMode(true);

      hideTooltip();
      clearToast();
      hideSocket();

      // Clear previous focus visuals without touching every path.
      clearTargetFeature();
      unhideSelectedFeature();
      baseLayer.classed("fm-has-focus", false);

      lastTargetFeature = f;
      setFeatureClass(f, "is-target", true);

      var fromT = S.currentTransform || d3.zoomIdentity;
      var toT = transformFor(f, fromHome);
      var dur = flightDuration(fromT, toT, fromHome);

      try {
        await flyTo(toT, dur);
      } catch (e) {
        setFlightRenderMode(false);
        return;
      }

      if (S.pendingFeature !== f) {
        setFlightRenderMode(false);
        return;
      }

      commitSelection(f, toT);
    }

    function commitSelection(f, t) {
      endFlightRenderMode();

      S.selectedFeature = f;
      S.pendingFeature = null;
      S.currentTransform = t;
      S.mode = "focused";

      clearTargetFeature();
      baseLayer.classed("fm-has-focus", true);
      setFeatureClass(f, "hidden-src", true);

      showSocket(f);
      showToast(f);
      showFocusCard(f);

      setShinyInput(el.id + "_selected", {
        id: f.properties.id || f.properties.feature_id,
        feature_id: f.properties.feature_id,
        name: f.properties.NAME,
        group: f.properties.group || null,
        properties: selectedProperties(f)
      });
    }

    async function clearFocus() {
      if (S.mode === "idle" || S.mode === "flying_home") return;

      S.mode = "flying_home";
      S.scrollOutCount = 0;
      clearTimeout(S.scrollOutTimer);

      setFlightRenderMode(true);

      hideTooltip();
      hideFocusCard();
      clearToast();
      hideSocket();

      baseLayer.classed("fm-has-focus", false);
      clearTargetFeature();
      unhideSelectedFeature();

      var fromT = S.currentTransform || d3.zoomIdentity;
      var toT = d3.zoomIdentity;
      var dur = flightDuration(fromT, toT, false);

      try {
        await flyTo(toT, dur);
      } catch (e) {}

      endFlightRenderMode();

      S.selectedFeature = null;
      S.pendingFeature = null;
      S.currentTransform = d3.zoomIdentity;
      S.mode = "idle";

      setShinyInput(el.id + "_selected", null);
    }

    function rebuildFocus(f) {
      setFlightRenderMode(false);

      var t = transformFor(f, false);
      S.currentTransform = t;

      svgEl.interrupt();
      svgEl.call(zoomBehaviour.transform, t);

      showSocket(f);
      showToast(f);
    }


    function onCountyClick(f) {
      if (S.mode === "idle" || S.mode === "focused") beginSelection(f);
    }

    function selectedProperties(f) {
      var props = f.properties || {};
      var out = {};
      var cols = opts.infoCols || [];
      var keys = opts.infoKeys || cols;

      cols.forEach(function (col, i) {
        var key = keys[i] || col;
        out[col] = props["info_" + key] == null ? null : props["info_" + key];
      });

      return out;
    }


    /* ── GeoJSON winding order fix ────────────────────────── */
    // D3's spherical geometry requires RFC 7946 winding order:
    //   exterior rings = counter-clockwise, holes = clockwise
    // If GDAL writes the old OGC convention (CW exterior), D3
    // interprets each polygon as its spherical complement —
    // "everything on Earth except this county" — causing the
    // blue-square bug. This function corrects winding in-place.
    function rewindFeatures(feats) {
      feats.forEach(function (f) {
        if (!f.geometry) return;
        var c = f.geometry.coordinates;
        if (f.geometry.type === "Polygon") {
          f.geometry.coordinates = rewindRings(c);
        } else if (f.geometry.type === "MultiPolygon") {
          f.geometry.coordinates = c.map(rewindRings);
        }
      });
    }

    function rewindRings(rings) {
      return rings.map(function (ring, i) {
        var a = ringArea(ring);
        // Exterior (i=0): CCW → positive signed area
        // Holes (i>0):   CW  → negative signed area
        if ((i === 0 && a < 0) || (i > 0 && a > 0)) ring.reverse();
        return ring;
      });
    }

    function ringArea(ring) {
      var n = ring.length, a = 0;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        a += ring[i][0] * ring[j][1] - ring[j][0] * ring[i][1];
      }
      return a / 2;
    }

    /* ── htmlwidgets interface ─────────────────────────────── */
    return {
      renderValue: function (x) {
        var geojson = (typeof x.geojson_str === "string")
          ? JSON.parse(x.geojson_str)
          : x.geojson_str;

        features = geojson.features;
        opts = x.options || {};

        // Auto-detect performance mode for dense county and municipal layers.
        // Caps max zoom scale and shortens transitions to keep SVG repaint smooth
        if (opts.performanceMode === undefined || opts.performanceMode === null) {
          opts.performanceMode = features.length > 100;
        }
        opts.performanceMode = !!opts.performanceMode;
        el.classList.toggle("fm-performance-mode", opts.performanceMode);

        features.forEach(function (f, i) {
          if (!f.properties.feature_id) f.properties.feature_id = String(i + 1);
          if (!f.properties.NAME) f.properties.NAME = f.properties.feature_id;
        });

        // Fix winding order before D3 touches the geometry
        rewindFeatures(features);

        // Remove previous keydown listener before buildDOM creates a new scope
        document.removeEventListener("keydown", onKey);

        buildDOM();
        buildColorScale();

        // Add keydown listener once per render (clean, no stacking)
        document.addEventListener("keydown", onKey);

        // Double rAF ensures the browser has laid out the SVG container
        // before we measure it with getBoundingClientRect(). Without this,
        // Shiny/htmlwidgets may not have assigned final dimensions yet,
        // causing fitProjection to compute a degenerate viewBox.
        requestAnimationFrame(function () {
          requestAnimationFrame(function () {
            fitProjection();
            renderPaths();
            svgEl.call(zoomBehaviour.transform, d3.zoomIdentity);
          });
        });

        S.mode = "idle";
        S.selectedFeature = null;
        S.pendingFeature = null;
        S.currentTransform = d3.zoomIdentity;
        lastTargetFeature = null;
      },

      resize: function (w, h) {
        width = w; height = h;
        if (!features || !features.length) return;
        fitProjection();
        renderPaths();
        if (S.mode === "focused" && S.selectedFeature) {
          rebuildFocus(S.selectedFeature);
        } else {
          svgEl.call(zoomBehaviour.transform, d3.zoomIdentity);
        }
      },

      getState: function () { return S; },
      clearFocus: clearFocus
    };
  }
});
