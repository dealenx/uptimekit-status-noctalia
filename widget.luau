--!nonstrict
-- UptimeKit status bar widget. Polls the public status page summary
-- (GET <base>[/<slug>]/summary.json) — no API key needed.
-- Docs: https://docs.uptimekit.dev/configuration/status_pages.md
-- Click opens the status page URL.

local BASE   = noctalia.getConfig("base_url")
local SLUG   = noctalia.getConfig("status_page_slug") or ""
local INTERVAL = (noctalia.getConfig("interval_sec") or 30) * 1000
local OPEN_URL = noctalia.getConfig("open_url_on_click") ~= false
local COMPACT  = noctalia.getConfig("compact") == true

local data = nil         -- decoded summary.json
local fetching = false

local function trimSlash(s) return (s:gsub("/+$", "")) end
local BASE_URL = trimSlash(BASE or "")

local function summaryUrl()
  local slug = SLUG:gsub("^/+", ""):gsub("/+$", "")
  if slug ~= "" then
    return BASE_URL .. "/" .. noctalia.string.urlEncode(slug) .. "/summary.json"
  end
  return BASE_URL .. "/summary.json"
end

local function pageUrl()
  return summaryUrl():gsub("/summary%.json$", "")
end

local function summarize(d)
  local total, bad = 0, 0
  for _, c in ipairs(d.components) do
    total = total + 1
    if c.status ~= "up" then bad = bad + 1 end
  end
  return total, bad
end

local function colorFor(d, bad, total)
  if total == 0 then return "#888888" end
  if bad == total then return "#e0483e" end
  if bad > 0 or (d.incidents and #d.incidents > 0) then return "#f2c14e" end
  if d.status == "unknown" then return "#f2c14e" end
  return "#37c871"
end

local function glyphFor(d, bad, total)
  if total == 0 or d.status == "unknown" then return "plug-connected" end
  if bad > 0 or (d.incidents and #d.incidents > 0) then return "alert-triangle" end
  return "circle-check"
end

local function statusLabelRu(s)
  local map = {
    down = "DOWN", degraded = "деградация",
    maintenance = "техработы", pending = "ожидание",
  }
  return map[s] or s
end

local function render()
  if not data then
    if fetching then
      barWidget.setGlyph("loader")
      barWidget.setText("…")
    else
      barWidget.setGlyph("plug-connected-x")
      barWidget.setGlyphColor("#e0483e")
      barWidget.setText(COMPACT and "ERR" or "UKit?")
    end
    return
  end
  local total, bad = summarize(data)
  local upN = total - bad
  barWidget.setGlyph(glyphFor(data, bad, total))
  barWidget.setGlyphColor(colorFor(data, bad, total))
  barWidget.setText(COMPACT and string.format("%d/%d", upN, total)
                    or string.format("%d/%d up", upN, total))

  local rows = {}
  local function row(k, v) rows[#rows + 1] = { key = k, value = v } end

  if #data.incidents > 0 then
    for _, inc in ipairs(data.incidents) do
      row("⚠ " .. inc.title, inc.status)
    end
  end
  if #data.maintenances > 0 then
    for _, m in ipairs(data.maintenances) do
      row("🛠 " .. m.title, m.status)
    end
  end

  local lastGroup = nil
  for _, c in ipairs(data.components) do
    if c.group and c.group ~= lastGroup then
      row("── " .. c.group .. " ──", "")
      lastGroup = c.group
    end
    local mark, val = "● ", "up"
    if c.status ~= "up" then
      mark, val = "○ ", statusLabelRu(c.status)
    end
    row(mark .. c.name, val)
  end

  if #rows == 0 then row("Пусто", "") end
  barWidget.setTooltip(rows)
end

-- Public JSON summary (no API key, cached 30 s server-side).
local function fetch()
  if fetching then return end
  fetching = true
  render()

  noctalia.http({ url = summaryUrl(), headers = { "Accept: application/json" } },
    function(res)
      fetching = false
      if not res.ok or res.status ~= 200 then
        noctalia.log("uptimekit-status: HTTP " .. tostring(res.status))
        data = nil
        barWidget.setGlyph("plug-connected-x")
        barWidget.setGlyphColor("#e0483e")
        barWidget.setText(COMPACT and "ERR" or "UKit offline")
        barWidget.setTooltip("HTTP " .. tostring(res.status))
        return
      end
      local ok, decoded = pcall(function() return noctalia.json.decode(res.body) end)
      if not ok or not decoded or type(decoded.components) ~= "table" then
        noctalia.log("uptimekit-status: bad payload")
        data = nil
        barWidget.setTooltip("bad payload")
        return
      end
      decoded.incidents = decoded.incidents or {}
      decoded.maintenances = decoded.maintenances or {}
      data = decoded
      render()
      -- Publish for the detail panel.
      noctalia.state.set("data", {
        pageName = decoded.page and decoded.page.name or "",
        pageUrl = decoded.page and decoded.page.url or pageUrl(),
        status = decoded.status,
        updatedAt = decoded.updatedAt,
        components = decoded.components,
        incidents = decoded.incidents,
        maintenances = decoded.maintenances,
      })
    end)
end

function update()
  noctalia.setUpdateInterval(INTERVAL)
  fetch()
end

-- Panel reads shared state on open; nothing to wire here.

function onClick()
  if OPEN_URL and BASE_URL ~= "" then
    noctalia.runAsync({ "xdg-open", pageUrl() })
  end
end

-- Manual refresh: noctalia msg plugin dealenx/uptimekit-status:ukit focused refresh
function onIpc(event)
  if event == "refresh" then
    fetch()
  end
end
