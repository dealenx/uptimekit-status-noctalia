--!nonstrict
-- Detail panel: page status, active incidents/maintenances, every component grouped.
-- Data comes from shared state "data" published by the widget entry.

local data = nil
local open = false

-- Data appears in shared state when the widget's first fetch completes.
noctalia.state.watch("data", function(v)
  if v then
    data = v
    if open then renderAll() end
  end
end)

local STATUS_COLOR = {
  up = "#37c871",
  down = "error",
  degraded = "warning",
  maintenance = "warning",
  pending = "on_surface_variant",
}

local function statusRu(s)
  local map = {
    up = "up", down = "DOWN", degraded = "деградация",
    maintenance = "техработы", pending = "ожидание",
    investigating = "расследуется", identified = "причина найдена",
    monitoring = "наблюдение", resolved = "решено",
    minor = "незначительный", major = "серьёзный", critical = "критический",
    scheduled = "запланировано", in_progress = "идёт", completed = "завершено",
    operational = "все системы работают",
    unknown = "нет данных",
  }
  return map[s] or s
end

function renderAll()
  if not data then
    panel.render(ui.column({ gap = 12 }, {
      ui.label({ text = "UptimeKit", fontSize = 16, fontWeight = "bold", color = "on_surface" }),
      ui.label({ text = "Нет данных — ещё не опрошено или ошибка сети.", color = "on_surface_variant" }),
    }))
    return
  end

  local rows = {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = (data.pageName ~= "" and data.pageName or "UptimeKit") .. " — статус",
                 fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
    }),
  }

  table.insert(rows, ui.label({
    text = statusRu(data.status),
    color = data.status == "operational" and "#37c871"
            or (data.status == "unknown" and "on_surface_variant" or "warning"),
    fontWeight = "medium",
  }))

  if #data.incidents > 0 then
    table.insert(rows, ui.label({ text = "Инциденты", color = "on_surface_variant", fontWeight = "bold" }))
    for _, inc in ipairs(data.incidents) do
      local sev = inc.severity and (" · " .. statusRu(inc.severity)) or ""
      table.insert(rows, ui.label({
        text = "⚠ " .. inc.title .. " — " .. statusRu(inc.status) .. sev,
        color = "warning",
      }))
    end
  end

  if #data.maintenances > 0 then
    table.insert(rows, ui.label({ text = "Техработы", color = "on_surface_variant", fontWeight = "bold" }))
    for _, m in ipairs(data.maintenances) do
      table.insert(rows, ui.label({
        text = "🛠 " .. m.title .. " — " .. statusRu(m.status),
        color = "warning",
      }))
    end
  end

  local total, bad = 0, 0
  for _, c in ipairs(data.components) do
    total = total + 1
    if c.status ~= "up" then bad = bad + 1 end
  end
  table.insert(rows, ui.label({
    text = string.format("Up %d из %d", total - bad, total),
    color = "primary",
    fontWeight = "medium",
  }))

  local lastGroup = nil
  for _, c in ipairs(data.components) do
    if c.group and c.group ~= lastGroup then
      table.insert(rows, ui.label({
        text = c.group,
        color = "on_surface_variant",
        fontWeight = "bold",
      }))
      lastGroup = c.group
    end
    table.insert(rows, ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({
        text = (c.status == "up" and "● " or "○ ") .. c.name,
        color = c.status == "up" and "#37c871" or "error",
        flexGrow = 1,
      }),
      ui.label({
        text = statusRu(c.status),
        color = STATUS_COLOR[c.status] or "on_surface_variant",
      }),
    }))
  end

  panel.render(ui.scroll({ flexGrow = 1, gap = 10 }, rows))
end

function onOpen(_context)
  open = true
  data = noctalia.state.get("data") or data
  renderAll()
end

function onClose()
  open = false
end

function onIpc(event, payload)
  if event == "data" and payload then
    data = payload
    renderAll()
  end
end
