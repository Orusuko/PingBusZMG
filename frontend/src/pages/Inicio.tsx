import { useEffect, useState } from 'react'
import { Search, ChevronRight, AlertTriangle, Zap, Settings } from 'lucide-react'
import { api, Ruta } from '../api'
import Badge from '../components/Badge'

interface Props {
  onSelectRuta: (clave: string) => void
}

// ── Configuración visual por tipo ──────────────────────────────────────────
const tipoConfig: Record<string, {
  emoji: string
  label: string
  claveBg: string
  claveText: string
  accentBorder: string
  chipBg: string
  chipText: string
  chipBorder: string
  glow: string
}> = {
  tren_ligero: {
    emoji: '🚊', label: 'Tren Ligero',
    claveBg: 'bg-violet-500', claveText: 'text-white',
    accentBorder: 'border-l-violet-500',
    chipBg: 'bg-violet-500/15', chipText: 'text-violet-300', chipBorder: 'border-violet-500/30',
    glow: 'shadow-violet-500/20',
  },
  autobus: {
    emoji: '🚍', label: 'Autobús',
    claveBg: 'bg-amber-500', claveText: 'text-white',
    accentBorder: 'border-l-amber-400',
    chipBg: 'bg-amber-500/15', chipText: 'text-amber-300', chipBorder: 'border-amber-500/30',
    glow: 'shadow-amber-500/20',
  },
  alimentador: {
    emoji: '🚌', label: 'Alimentador',
    claveBg: 'bg-sky-500', claveText: 'text-white',
    accentBorder: 'border-l-sky-400',
    chipBg: 'bg-sky-500/15', chipText: 'text-sky-300', chipBorder: 'border-sky-500/30',
    glow: 'shadow-sky-500/20',
  },
  BRT: {
    emoji: '⚡', label: 'BRT',
    claveBg: 'bg-rose-500', claveText: 'text-white',
    accentBorder: 'border-l-rose-400',
    chipBg: 'bg-rose-500/15', chipText: 'text-rose-300', chipBorder: 'border-rose-500/30',
    glow: 'shadow-rose-500/20',
  },
}

const defaultConfig = tipoConfig.autobus

export default function Inicio({ onSelectRuta }: Props) {
  const [rutas, setRutas]       = useState<Ruta[]>([])
  const [busqueda, setBusqueda] = useState('')
  const [loading, setLoading]   = useState(true)
  const [error, setError]       = useState(false)

  useEffect(() => { cargar() }, [])

  const cargar = async () => {
    setLoading(true); setError(false)
    try { setRutas(await api.getRutas()) }
    catch { setError(true) }
    finally { setLoading(false) }
  }

  const filtradas = rutas.filter(
    r =>
      r.clave.toLowerCase().includes(busqueda.toLowerCase()) ||
      r.nombre.toLowerCase().includes(busqueda.toLowerCase())
  )

  // Agrupar manteniendo orden de aparición
  const grupos: { tipo: string; lista: Ruta[] }[] = []
  const seen = new Set<string>()
  for (const r of filtradas) {
    if (!seen.has(r.tipo)) { seen.add(r.tipo); grupos.push({ tipo: r.tipo, lista: [] }) }
    grupos.find(g => g.tipo === r.tipo)!.lista.push(r)
  }

  return (
    <div className="flex flex-col min-h-dvh pb-24 bg-slate-900 page-enter">

      {/* ── Hero ──────────────────────────────────────────────────────── */}
      <div className="bg-slate-900 dot-pattern px-4 pt-12 pb-6 relative overflow-hidden">
        <div className="absolute -top-10 -right-10 w-52 h-52 bg-indigo-600/20 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-36 h-36 bg-violet-600/15 rounded-full blur-2xl pointer-events-none" />

        <div className="max-w-[430px] mx-auto relative">
          {/* Barra superior */}
          <div className="flex items-center gap-2 mb-4">
            <div className="w-8 h-8 bg-indigo-500 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-500/30">
              <Zap size={16} className="text-white" fill="white" />
            </div>
            <span className="text-white font-bold text-[15px] tracking-tight">VíaSync</span>
            <span className="text-slate-500 text-[13px]">ZMG</span>

            {/* Live badge */}
            <div className="flex items-center gap-1.5 bg-green-500/15 border border-green-500/25 rounded-full px-2.5 py-1">
              <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
              <span className="text-green-300 text-[11px] font-semibold">En vivo</span>
            </div>

            {/* Acceso discreto al panel de sistema */}
            <a
              href="#sistema"
              className="ml-auto w-8 h-8 flex items-center justify-center rounded-lg hover:bg-white/10 active:bg-white/15 transition-colors"
              title="Panel del sistema"
            >
              <Settings size={15} className="text-slate-500" />
            </a>
          </div>

          <h1 className="text-white text-[26px] font-extrabold tracking-tight leading-tight">
            Transporte público<br />
            <span className="text-indigo-400">Guadalajara</span>
          </h1>
          <p className="text-slate-400 text-[13px] mt-1.5">
            {loading ? 'Cargando rutas…' : `${rutas.length} rutas disponibles en tiempo real`}
          </p>

          {/* Buscador */}
          <div className="relative mt-5">
            <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
            <input
              type="search"
              placeholder="Buscar ruta…  ej: L1, Periférico"
              value={busqueda}
              onChange={e => setBusqueda(e.target.value)}
              className="w-full pl-9 pr-4 py-3 bg-white/8 border border-white/12 rounded-xl text-[14px] text-white placeholder-slate-600 outline-none focus:bg-white/12 focus:border-white/20 transition-colors"
            />
          </div>
        </div>
      </div>

      {/* ── Contenido ─────────────────────────────────────────────────── */}
      <div className="flex-1 px-4 pt-5 max-w-[430px] mx-auto w-full">

        {/* Skeletons */}
        {loading && (
          <div className="space-y-5">
            {[3, 1].map((n, gi) => (
              <div key={gi}>
                <div className="h-7 w-36 bg-white/8 rounded-lg animate-pulse mb-2.5" />
                <div className="rounded-2xl overflow-hidden border border-white/8 space-y-px">
                  {[...Array(n)].map((_, i) => (
                    <div key={i} className="h-[62px] bg-white/5 animate-pulse" style={{ animationDelay: `${i * 80}ms` }} />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Error */}
        {error && !loading && (
          <div className="flex flex-col items-center text-center py-16">
            <div className="w-14 h-14 bg-red-500/15 border border-red-500/25 rounded-2xl flex items-center justify-center mb-4">
              <AlertTriangle size={24} className="text-red-400" />
            </div>
            <p className="text-[15px] font-bold text-white">Sin conexión</p>
            <p className="text-[13px] text-slate-400 mt-1 mb-5">No se pudo contactar al servidor</p>
            <button onClick={cargar}
              className="px-6 py-2.5 bg-white/10 border border-white/15 text-white text-[13px] font-semibold rounded-xl active:scale-95 transition-transform">
              Reintentar
            </button>
          </div>
        )}

        {/* Grupos */}
        {!loading && !error && (
          <>
            {grupos.map(({ tipo, lista }) => {
              const cfg = tipoConfig[tipo] ?? defaultConfig
              return (
                <section key={tipo} className="mb-6">
                  {/* ── Header de categoría ── */}
                  <div className={`inline-flex items-center gap-2 mb-3 px-3 py-1.5 rounded-xl border ${cfg.chipBg} ${cfg.chipBorder}`}>
                    <span className="text-[14px] leading-none">{cfg.emoji}</span>
                    <span className={`text-[12px] font-bold tracking-wide ${cfg.chipText}`}>
                      {cfg.label}
                    </span>
                    <span className={`text-[11px] font-semibold px-1.5 py-0.5 rounded-md bg-white/10 ${cfg.chipText}`}>
                      {lista.length}
                    </span>
                  </div>

                  {/* Cards */}
                  <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden divide-y divide-white/8 shadow-lg">
                    {lista.map(r => <RutaRow key={r.clave} ruta={r} cfg={cfg} onSelect={onSelectRuta} />)}
                  </div>
                </section>
              )
            })}

            {filtradas.length === 0 && (
              <div className="text-center py-16">
                <p className="text-[15px] font-semibold text-white">Sin resultados</p>
                <p className="text-[13px] text-slate-400 mt-1">No hay rutas con "{busqueda}"</p>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}

function RutaRow({ ruta, cfg, onSelect }: {
  ruta: Ruta
  cfg: typeof tipoConfig[string]
  onSelect: (c: string) => void
}) {
  return (
    <button
      onClick={() => onSelect(ruta.clave)}
      className={`w-full flex items-center gap-3 px-4 py-3.5 active:bg-white/8 transition-colors text-left border-l-[3px] ${cfg.accentBorder}`}
    >
      <span className={`min-w-[44px] text-center text-[12px] font-extrabold py-1.5 px-1 rounded-lg flex-shrink-0 ${cfg.claveBg} ${cfg.claveText} shadow-sm`}>
        {ruta.clave}
      </span>
      <div className="flex-1 min-w-0">
        <p className="text-[14px] font-medium text-white truncate leading-tight">{ruta.nombre}</p>
      </div>
      <div className="flex items-center gap-2 flex-shrink-0">
        <Badge tipo={ruta.tipo} />
        <ChevronRight size={14} className="text-white/25" />
      </div>
    </button>
  )
}
