import { useEffect, useState, useCallback } from 'react'
import { MapPin, RefreshCw, Users, ChevronDown, ChevronUp, AlertTriangle, Info } from 'lucide-react'
import { MapContainer, TileLayer, Marker, Circle, Popup, Polyline, useMap } from 'react-leaflet'
import L from 'leaflet'
import { api, ConsultaResponse, UnidadDetectada, TrazadoResponse } from '../api'
import TopBar from '../components/TopBar'

delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl:       'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl:     'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
})

const mkBusIcon = (active: boolean) => L.divIcon({
  html: `<div style="
    width:36px;height:36px;border-radius:50%;
    background:${active ? '#6366f1' : '#475569'};
    border:2.5px solid ${active ? '#818cf8' : '#64748b'};
    box-shadow:0 2px 12px rgba(0,0,0,0.5);
    display:flex;align-items:center;justify-content:center;
    font-size:16px;
  ">🚌</div>`,
  className: '',
  iconSize: [36, 36],
  iconAnchor: [18, 18],
})

const mkParadaIcon = (isFirst: boolean, isLast: boolean) => L.divIcon({
  html: `<div style="
    width:12px;height:12px;border-radius:50%;
    background:${isFirst ? '#22c55e' : isLast ? '#ef4444' : '#6366f1'};
    border:2px solid white;
    box-shadow:0 1px 4px rgba(0,0,0,0.5);
  "></div>`,
  className: '',
  iconSize: [12, 12],
  iconAnchor: [6, 6],
})

// Componente para ajustar el bounds del mapa al trazado
function FitBounds({ positions }: { positions: [number, number][] }) {
  const map = useMap()
  useEffect(() => {
    if (positions.length >= 2) {
      map.fitBounds(positions, { padding: [24, 24], maxZoom: 15 })
    }
  }, [map, positions])
  return null
}

const tipoColor: Record<string, string> = {
  tren_ligero: '#8b5cf6',
  autobus:     '#f59e0b',
  alimentador: '#38bdf8',
  BRT:         '#f43f5e',
}

interface Props {
  clave: string
  onBack: () => void
}

export default function DetalleRuta({ clave, onBack }: Props) {
  const [data, setData]             = useState<ConsultaResponse | null>(null)
  const [trazado, setTrazado]       = useState<TrazadoResponse | null>(null)
  const [loading, setLoading]       = useState(true)
  const [error, setError]           = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null)
  const [expanded, setExpanded]     = useState<number | null>(null)
  const [showParadas, setShowParadas] = useState(true)

  const cargar = useCallback(async (silent = false) => {
    if (!silent) setLoading(true); else setRefreshing(true)
    setError(false)
    try {
      const [res, traz] = await Promise.all([
        api.consultarRuta(clave),
        api.getTrazado(clave),
      ])
      setData(res)
      setTrazado(traz)
      setLastUpdate(new Date())
    } catch { setError(true) }
    finally { setLoading(false); setRefreshing(false) }
  }, [clave])

  useEffect(() => {
    cargar()
    const id = setInterval(() => cargar(true), 30_000)
    return () => clearInterval(id)
  }, [cargar])

  const unidades = data?.unidades ?? []
  const centro: [number, number] = [20.6597, -103.3496]

  // Construir polyline desde GeoJSON LineString (coordenadas en [lon, lat] → invertir a [lat, lon])
  const polylinePositions: [number, number][] =
    trazado?.trazado?.coordinates?.map(([lon, lat]) => [lat, lon]) ?? []

  const routeColor = tipoColor[trazado?.tipo ?? ''] ?? '#6366f1'

  const tiempoDesde = (iso: string | null) => {
    if (!iso) return 'justo ahora'
    const s = Math.round((Date.now() - new Date(iso).getTime()) / 1000)
    if (s < 60) return `hace ${s}s`
    return `hace ${Math.round(s / 60)} min`
  }

  const rightAction = (
    <button
      onClick={() => cargar(true)}
      className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-white/10 active:bg-white/15 transition-colors"
    >
      <RefreshCw size={16} className={`text-slate-400 ${refreshing ? 'animate-spin' : ''}`} />
    </button>
  )

  return (
    <div className="flex flex-col h-dvh bg-slate-900 page-enter">
      <TopBar
        title={`Ruta ${clave}`}
        subtitle={lastUpdate
          ? `Actualizado ${lastUpdate.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })}`
          : 'Cargando…'}
        onBack={onBack}
        right={rightAction}
      />

      {/* Mapa */}
      <div className="relative mx-3 mt-3 rounded-2xl overflow-hidden border border-white/10 flex-shrink-0" style={{ height: '240px' }}>
        {loading && (
          <div className="absolute inset-0 bg-slate-800 flex items-center justify-center z-10">
            <div className="w-7 h-7 border-2 border-indigo-400 border-t-transparent rounded-full animate-spin" />
          </div>
        )}
        <MapContainer center={centro} zoom={13} zoomControl={false} className="w-full h-full">
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            attribution='© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors © <a href="https://carto.com/">CARTO</a>'
          />

          {/* Ajustar bounds al trazado */}
          {polylinePositions.length >= 2 && (
            <FitBounds positions={polylinePositions} />
          )}

          {/* ── Trazado oficial de la ruta ── */}
          {polylinePositions.length >= 2 && (
            <>
              {/* Sombra/halo de la línea */}
              <Polyline
                positions={polylinePositions}
                pathOptions={{ color: routeColor, weight: 10, opacity: 0.15 }}
              />
              {/* Línea principal */}
              <Polyline
                positions={polylinePositions}
                pathOptions={{ color: routeColor, weight: 3.5, opacity: 0.9, dashArray: undefined }}
              />
            </>
          )}

          {/* ── Paradas ── */}
          {showParadas && trazado?.paradas.map((p, i) => {
            const isFirst = i === 0
            const isLast  = i === trazado.paradas.length - 1
            return (
              <Marker
                key={p.orden}
                position={[p.lat, p.lon]}
                icon={mkParadaIcon(isFirst, isLast)}
              >
                <Popup>
                  <div className="text-xs">
                    <span className={`font-bold ${isFirst ? 'text-green-600' : isLast ? 'text-red-600' : 'text-indigo-600'}`}>
                      {isFirst ? '🟢 Inicio' : isLast ? '🔴 Final' : `Parada ${p.orden}`}
                    </span>
                    <br />{p.nombre}
                  </div>
                </Popup>
              </Marker>
            )
          })}

          {/* ── Unidades detectadas ── */}
          {unidades.map(u => (
            <div key={u.unidad_id}>
              <Marker
                position={[u.posicion.lat, u.posicion.lon]}
                icon={mkBusIcon(expanded === u.unidad_id)}
                eventHandlers={{ click: () => setExpanded(p => p === u.unidad_id ? null : u.unidad_id) }}
              >
                <Popup><span className="text-xs font-semibold">Unidad #{u.unidad_id}</span></Popup>
              </Marker>
              <Circle
                center={[u.posicion.lat, u.posicion.lon]}
                radius={20}
                pathOptions={{ color: '#6366f1', fillColor: '#6366f1', fillOpacity: 0.2, weight: 1.5 }}
              />
            </div>
          ))}
        </MapContainer>

        {/* Controles del mapa */}
        <div className="absolute bottom-3 left-3 z-20 flex items-center gap-2">
          {/* Estado de unidades */}
          <div className="bg-slate-900/90 backdrop-blur-sm rounded-full px-3 py-1.5 border border-white/15 flex items-center gap-2">
            <span className={`w-2 h-2 rounded-full flex-shrink-0 ${unidades.length > 0 ? 'bg-green-400 animate-pulse' : 'bg-slate-500'}`} />
            <span className="text-xs font-semibold text-white">
              {unidades.length > 0
                ? `${unidades.length} unidad${unidades.length !== 1 ? 'es' : ''}`
                : 'Sin unidades'}
            </span>
          </div>
          {/* Toggle paradas */}
          {trazado && (
            <button
              onClick={() => setShowParadas(v => !v)}
              className={`px-2.5 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                showParadas
                  ? 'bg-indigo-500/30 border-indigo-400/40 text-indigo-200'
                  : 'bg-slate-900/90 border-white/15 text-slate-400'
              }`}
            >
              <MapPin size={11} className="inline mr-1" />Paradas
            </button>
          )}
        </div>
      </div>

      {/* Leyenda de paradas */}
      {trazado && trazado.paradas.length > 0 && (
        <div className="mx-3 mt-2 flex items-center gap-3 px-3 py-2 bg-white/5 border border-white/10 rounded-xl">
          <Info size={13} className="text-slate-400 flex-shrink-0" />
          <div className="flex items-center gap-3 text-[12px] text-slate-400 min-w-0 flex-1 overflow-hidden">
            <span className="flex items-center gap-1 flex-shrink-0">
              <span className="w-2.5 h-2.5 rounded-full bg-green-500 inline-block" />
              {trazado.paradas[0]?.nombre}
            </span>
            <span className="text-white/20 flex-shrink-0">→</span>
            <span className="flex items-center gap-1 flex-shrink-0">
              <span className="w-2.5 h-2.5 rounded-full bg-red-500 inline-block" />
              {trazado.paradas[trazado.paradas.length - 1]?.nombre}
            </span>
            <span className="ml-auto flex-shrink-0 text-slate-500">{trazado.paradas.length} paradas</span>
          </div>
        </div>
      )}

      {/* Lista de unidades */}
      <div className="flex-1 overflow-y-auto px-3 py-3 pb-6 space-y-2">
        {!loading && !error && unidades.length === 0 && (
          <div className="text-center py-12">
            <div className="w-14 h-14 bg-white/5 border border-white/10 rounded-2xl flex items-center justify-center mx-auto mb-3 text-2xl">🔭</div>
            <p className="text-[15px] font-semibold text-white">Sin unidades activas</p>
            <p className="text-[13px] text-slate-400 mt-1">No hay reportes en los últimos 2 minutos</p>
          </div>
        )}

        {error && (
          <div className="flex items-center gap-3 bg-red-500/15 border border-red-500/25 rounded-xl p-4">
            <AlertTriangle size={17} className="text-red-400 flex-shrink-0" />
            <div className="flex-1">
              <p className="text-[14px] font-semibold text-red-300">Error al cargar</p>
              <p className="text-[12px] text-red-400/70 mt-px">Verifica tu conexión</p>
            </div>
            <button onClick={() => cargar()} className="text-[12px] font-semibold text-red-300 bg-red-500/20 border border-red-500/25 px-3 py-1.5 rounded-lg active:scale-95 transition-transform">
              Reintentar
            </button>
          </div>
        )}

        {unidades.map(u => (
          <UnidadCard
            key={u.unidad_id}
            unidad={u}
            open={expanded === u.unidad_id}
            onToggle={() => setExpanded(p => p === u.unidad_id ? null : u.unidad_id)}
            tiempoDesde={tiempoDesde}
          />
        ))}
      </div>
    </div>
  )
}

function ConfianzaBar({ value }: { value: number }) {
  const pct   = Math.min(value / 5, 1)
  const color = value >= 3 ? 'bg-green-500' : value === 2 ? 'bg-amber-400' : 'bg-slate-500'
  return (
    <div className="flex items-center gap-1.5 mt-0.5">
      <div className="flex-1 h-1 bg-white/10 rounded-full overflow-hidden">
        <div className={`h-full rounded-full ${color}`} style={{ width: `${pct * 100}%` }} />
      </div>
      <span className="text-[11px] text-slate-500 flex items-center gap-0.5">
        <Users size={9} /> {value}
      </span>
    </div>
  )
}

function UnidadCard({ unidad, open, onToggle, tiempoDesde }: {
  unidad: UnidadDetectada
  open: boolean
  onToggle: () => void
  tiempoDesde: (iso: string | null) => string
}) {
  return (
    <div className={`rounded-2xl border overflow-hidden transition-all ${
      open ? 'bg-white/8 border-indigo-500/40' : 'bg-white/5 border-white/10'
    }`}>
      <button onClick={onToggle} className="w-full px-4 py-3.5 flex items-center gap-3 text-left">
        <div className={`w-9 h-9 rounded-xl flex items-center justify-center text-base flex-shrink-0 ${open ? 'bg-indigo-500/20' : 'bg-white/8'}`}>
          🚌
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-[14px] font-semibold text-white">Unidad #{unidad.unidad_id}</p>
          <ConfianzaBar value={unidad.confianza} />
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          <span className="text-[11px] text-slate-500">{tiempoDesde(unidad.ultima_actualizacion)}</span>
          {open ? <ChevronUp size={15} className="text-slate-500" /> : <ChevronDown size={15} className="text-slate-500" />}
        </div>
      </button>

      {open && unidad.proximas_paradas.length > 0 && (
        <div className="border-t border-white/8 px-4 py-3 space-y-2.5">
          <p className="text-[11px] font-bold text-slate-500 uppercase tracking-widest">Próximas paradas</p>
          {unidad.proximas_paradas.slice(0, 3).map((p, i) => (
            <div key={i} className="flex items-center gap-3">
              <div className="w-6 h-6 rounded-full bg-indigo-500/20 flex items-center justify-center flex-shrink-0">
                <MapPin size={12} className="text-indigo-400" />
              </div>
              <span className="flex-1 text-[13px] text-slate-300 font-medium truncate">{p.nombre}</span>
              <div className="text-right flex-shrink-0">
                <p className="text-[13px] font-bold text-indigo-400">{Math.round(p.eta_minutos)} min</p>
                <p className="text-[11px] text-slate-500">{Math.round(p.distancia_m)} m</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
