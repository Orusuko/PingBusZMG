import { useEffect, useState } from 'react'
import { RefreshCw, Activity, Bus, Layers, Database, BarChart3, ArrowLeft } from 'lucide-react'
import { api, EstadisticasResponse } from '../api'

const rutaAccent: Record<string, string> = {
  tren_ligero: 'bg-violet-500',
  autobus:     'bg-amber-400',
  alimentador: 'bg-sky-400',
  BRT:         'bg-rose-400',
}

export default function Estadisticas() {
  const [data, setData]         = useState<EstadisticasResponse | null>(null)
  const [health, setHealth]     = useState<{ status: string; postgis: string } | null>(null)
  const [loading, setLoading]   = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null)

  const cargar = async (silent = false) => {
    if (!silent) setLoading(true); else setRefreshing(true)
    try {
      const [stats, h] = await Promise.all([api.getEstadisticas(), api.getHealth()])
      setData(stats); setHealth(h); setLastUpdate(new Date())
    } catch { /* silencioso */ }
    finally { setLoading(false); setRefreshing(false) }
  }

  useEffect(() => {
    cargar()
    const id = setInterval(() => cargar(true), 30_000)
    return () => clearInterval(id)
  }, [])

  const totalUnidades = data?.rutas.reduce((s, r) => s + r.unidades_detectadas, 0) ?? 0
  const rutasActivas  = data?.rutas.filter(r => r.pings_activos > 0).length ?? 0
  const isOk = health?.status === 'ok'

  return (
    <div className="flex flex-col min-h-dvh bg-slate-900 page-enter">

      {/* TopBar manual (sin BottomNav en esta página) */}
      <header className="sticky top-0 z-40 bg-slate-900/95 backdrop-blur-md border-b border-white/10 px-4 py-3">
        <div className="max-w-[430px] mx-auto flex items-center gap-3 h-10">
          <a
            href="#"
            onClick={() => window.history.back()}
            className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-white/10 active:bg-white/15 transition-colors -ml-1"
          >
            <ArrowLeft size={19} className="text-white" />
          </a>
          <div className="flex-1">
            <h1 className="text-[15px] font-semibold text-white">Panel del sistema</h1>
            <p className="text-[12px] text-slate-400">
              {lastUpdate ? `Actualizado ${lastUpdate.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })}` : 'Cargando…'}
            </p>
          </div>
          <button onClick={() => cargar(true)} className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-white/10 active:bg-white/15 transition-colors">
            <RefreshCw size={16} className={`text-slate-400 ${refreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </header>

      {/* Hero */}
      <div className="bg-slate-900 dot-pattern px-4 pt-6 pb-6 relative overflow-hidden">
        <div className="absolute -top-8 right-0 w-44 h-44 bg-emerald-600/15 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 -left-6 w-32 h-32 bg-sky-600/15 rounded-full blur-2xl pointer-events-none" />
        <div className="max-w-[430px] mx-auto relative">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-8 h-8 bg-emerald-500 rounded-xl flex items-center justify-center shadow-lg shadow-emerald-500/30">
              <BarChart3 size={15} className="text-white" />
            </div>
            <span className="text-slate-400 text-[13px] font-medium">Dashboard operativo</span>
          </div>
          <h1 className="text-white text-[24px] font-extrabold tracking-tight leading-tight">
            Estadísticas <span className="text-emerald-400">en vivo</span>
          </h1>
        </div>
      </div>

      <div className="flex-1 px-4 pt-4 max-w-[430px] mx-auto w-full pb-8">

        {/* Métricas */}
        <div className="grid grid-cols-2 gap-2.5 mb-5">
          {loading && !data ? (
            [...Array(4)].map((_, i) => (
              <div key={i} className="h-28 bg-white/5 rounded-2xl animate-pulse" style={{ animationDelay: `${i * 70}ms` }} />
            ))
          ) : (
            <>
              <MetricCard icon={<Activity size={18} className="text-blue-400" />}
                label="Pings activos" value={data?.pings_activos_total ?? 0}
                sub={`ventana ${data?.ventana_minutos ?? 2} min`} bg="bg-blue-500/15" />
              <MetricCard icon={<Bus size={18} className="text-amber-400" />}
                label="Unidades" value={totalUnidades}
                sub="detectadas ahora" bg="bg-amber-500/15" />
              <MetricCard icon={<Layers size={18} className="text-violet-400" />}
                label="Rutas activas" value={rutasActivas}
                sub={`de ${data?.rutas.length ?? 0} totales`} bg="bg-violet-500/15" />
              <MetricCard icon={<Database size={18} className="text-emerald-400" />}
                label="Base de datos" value={0}
                sub={isOk ? 'Operativa' : 'Sin conexión'}
                bg="bg-emerald-500/15" isStatus statusOk={isOk} />
            </>
          )}
        </div>

        {/* PostGIS */}
        {health && (
          <div className="bg-white/5 border border-white/10 rounded-2xl px-4 py-3.5 flex items-center gap-3 mb-5">
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${isOk ? 'bg-emerald-500/20' : 'bg-red-500/20'}`}>
              <span className={`w-3 h-3 rounded-full ${isOk ? 'bg-emerald-400 animate-pulse' : 'bg-red-400'}`} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-[14px] font-semibold text-white">PostgreSQL · PostGIS</p>
              <p className="text-[11px] text-slate-500 font-mono truncate">{health.postgis.split(' ')[0]}</p>
            </div>
            <span className={`text-[11px] font-bold px-2.5 py-1 rounded-full ${isOk ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'}`}>
              {isOk ? 'OK' : 'Error'}
            </span>
          </div>
        )}

        {/* Tabla rutas */}
        <p className="text-[11px] font-bold text-slate-500 uppercase tracking-widest mb-2 px-1">Detalle por ruta</p>
        <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
          {loading && !data ? (
            <div className="divide-y divide-white/8">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="flex items-center gap-3 px-4 py-3.5">
                  <div className="w-9 h-9 bg-white/8 rounded-xl animate-pulse" />
                  <div className="flex-1 space-y-2">
                    <div className="h-3 bg-white/8 rounded animate-pulse w-16" />
                    <div className="h-2.5 bg-white/8 rounded animate-pulse w-28" />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="divide-y divide-white/8">
              {(data?.rutas ?? []).map(r => {
                const dot = rutaAccent[r.tipo ?? ''] ?? 'bg-slate-500'
                return (
                  <div key={r.clave} className="flex items-center gap-3 px-4 py-3.5">
                    <div className="relative w-9 h-9 rounded-xl bg-white/8 border border-white/10 flex items-center justify-center flex-shrink-0">
                      <span className="text-[11px] font-extrabold text-white">{r.clave.slice(0, 2)}</span>
                      <span className={`absolute -top-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border-2 border-slate-900 ${r.pings_activos > 0 ? dot : 'bg-slate-600'}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[14px] font-semibold text-white">{r.clave}</p>
                      <p className="text-[12px] text-slate-400">
                        {r.pings_activos} ping{r.pings_activos !== 1 ? 's' : ''}
                        {r.unidades_detectadas > 0 && ` · ${r.unidades_detectadas} unidad${r.unidades_detectadas !== 1 ? 'es' : ''}`}
                      </p>
                    </div>
                    {r.pings_activos > 0 && (
                      <span className="text-[11px] font-semibold text-emerald-400 bg-emerald-500/15 border border-emerald-500/20 px-2 py-0.5 rounded-full">
                        Activa
                      </span>
                    )}
                  </div>
                )
              })}
              {!loading && data?.rutas.length === 0 && (
                <div className="text-center py-10 text-[13px] text-slate-500">Sin datos</div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function MetricCard({ icon, label, value, sub, bg, isStatus, statusOk }: {
  icon: React.ReactNode; label: string; value: number; sub: string; bg: string
  isStatus?: boolean; statusOk?: boolean
}) {
  return (
    <div className="bg-white/5 border border-white/10 rounded-2xl p-4">
      <div className={`w-9 h-9 rounded-xl ${bg} flex items-center justify-center mb-3`}>{icon}</div>
      {isStatus ? (
        <p className={`text-xl font-extrabold tracking-tight ${statusOk ? 'text-emerald-400' : 'text-red-400'}`}>
          {statusOk ? 'Online' : 'Offline'}
        </p>
      ) : (
        <p className="text-2xl font-extrabold text-white tracking-tight">{value.toLocaleString()}</p>
      )}
      <p className="text-[12px] font-semibold text-slate-300 mt-0.5">{label}</p>
      <p className="text-[11px] text-slate-500">{sub}</p>
    </div>
  )
}
