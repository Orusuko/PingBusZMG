import { useState, useEffect } from 'react'
import { Navigation, CheckCircle, XCircle, Loader2, Lock, MapPin, Radio } from 'lucide-react'
import { api, Ruta } from '../api'

const SESSION_KEY = 'viasync_session_id'
function getSessionId(): string {
  let id = localStorage.getItem(SESSION_KEY)
  if (!id) { id = crypto.randomUUID(); localStorage.setItem(SESSION_KEY, id) }
  return id
}

type Status = 'idle' | 'locating' | 'sending' | 'ok' | 'error' | 'ratelimit'

export default function Reportar() {
  const [rutas, setRutas]       = useState<Ruta[]>([])
  const [ruta, setRuta]         = useState('')
  const [status, setStatus]     = useState<Status>('idle')
  const [errorMsg, setErrorMsg] = useState('')
  const [coords, setCoords]     = useState<{ lat: number; lon: number } | null>(null)
  const [cooldown, setCooldown] = useState(0)

  useEffect(() => { api.getRutas().then(setRutas).catch(() => {}) }, [])

  useEffect(() => {
    if (cooldown <= 0) return
    const t = setInterval(() => setCooldown(c => Math.max(0, c - 1)), 1000)
    return () => clearInterval(t)
  }, [cooldown])

  const getPos = (): Promise<GeolocationPosition> =>
    new Promise((res, rej) => {
      if (!navigator.geolocation) { rej(new Error('GPS no disponible')); return }
      navigator.geolocation.getCurrentPosition(res, rej, { enableHighAccuracy: true, timeout: 10_000 })
    })

  const handleSubmit = async () => {
    if (!ruta || cooldown > 0) return
    setStatus('locating'); setErrorMsg('')
    let lat: number, lon: number
    try {
      const p = await getPos()
      lat = p.coords.latitude; lon = p.coords.longitude
      setCoords({ lat, lon })
    } catch {
      setStatus('error'); setErrorMsg('Activa el GPS para reportar')
      return
    }
    setStatus('sending')
    try {
      await api.reportar(getSessionId(), ruta, lat, lon)
      setStatus('ok'); setCooldown(12)
      setTimeout(() => setStatus('idle'), 5000)
    } catch (e: unknown) {
      const err = e as { response?: { status: number; data?: { detail?: string } } }
      const code   = err?.response?.status
      const detail = err?.response?.data?.detail ?? ''
      setStatus(code === 429 ? 'ratelimit' : 'error')
      if (code === 429) {
        setCooldown(10); setTimeout(() => setStatus('idle'), 3000)
      } else if (code === 422) {
        // Muestra el mensaje exacto del trigger de PostgreSQL (incluye distancia)
        setErrorMsg(detail.replace('Ubicación rechazada: ', '') || 'Ubicación fuera del área de la ruta')
      } else if (code === 404) {
        setErrorMsg('Ruta no encontrada o inactiva')
      } else {
        setErrorMsg('Error al enviar. Intenta de nuevo.')
      }
      if (code !== 429) setTimeout(() => setStatus('idle'), 6000)
    }
  }

  const busy = status === 'locating' || status === 'sending' || cooldown > 0

  return (
    <div className="flex flex-col min-h-dvh pb-24 bg-slate-900 page-enter">

      {/* Hero */}
      <div className="bg-slate-900 dot-pattern px-4 pt-12 pb-6 relative overflow-hidden">
        <div className="absolute -top-8 -left-8 w-44 h-44 bg-violet-600/20 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 right-0 w-32 h-32 bg-indigo-600/15 rounded-full blur-2xl pointer-events-none" />
        <div className="max-w-[430px] mx-auto relative">
          <div className="flex items-center gap-2 mb-4">
            <div className="w-8 h-8 bg-violet-500 rounded-xl flex items-center justify-center shadow-lg shadow-violet-500/30">
              <Radio size={15} className="text-white" />
            </div>
            <span className="text-slate-400 text-[13px] font-medium">Modo colaborativo</span>
          </div>
          <h1 className="text-white text-[26px] font-extrabold tracking-tight leading-tight">
            Reportar<br />
            <span className="text-violet-400">mi ubicación</span>
          </h1>
          <p className="text-slate-400 text-[13px] mt-1.5">Ayuda a otros usuarios del transporte</p>
        </div>
      </div>

      <div className="flex-1 px-4 pt-5 max-w-[430px] mx-auto w-full space-y-4">

        {/* Privacidad */}
        <div className="flex items-start gap-3 bg-white/5 border border-white/10 rounded-2xl p-4">
          <div className="w-8 h-8 bg-white/8 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
            <Lock size={14} className="text-slate-300" />
          </div>
          <div>
            <p className="text-[13px] font-semibold text-white">Tu privacidad está protegida</p>
            <p className="text-[12px] text-slate-400 mt-0.5 leading-relaxed">
              Tu ID se anonimiza con SHA-256. Datos eliminados automáticamente en 2 min.
            </p>
          </div>
        </div>

        {/* Selector */}
        <div>
          <label className="text-[11px] font-bold text-slate-500 uppercase tracking-widest block mb-2">
            ¿En qué ruta vas?
          </label>
          <div className="relative bg-white/8 border border-white/12 rounded-xl overflow-hidden">
            <select
              value={ruta}
              onChange={e => setRuta(e.target.value)}
              disabled={busy}
              className="w-full px-4 py-3.5 text-[14px] text-white bg-transparent appearance-none outline-none disabled:text-slate-500 cursor-pointer"
              style={{ colorScheme: 'dark' }}
            >
              <option value="" className="bg-slate-800">Selecciona una ruta…</option>
              {rutas.map(r => (
                <option key={r.clave} value={r.clave} className="bg-slate-800">{r.clave} — {r.nombre}</option>
              ))}
            </select>
            <svg className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="m6 9 6 6 6-6"/>
            </svg>
          </div>
        </div>

        {/* GPS */}
        {coords && (
          <div className="flex items-center gap-3 bg-emerald-500/15 border border-emerald-500/25 rounded-xl px-4 py-3">
            <MapPin size={15} className="text-emerald-400 flex-shrink-0" />
            <div>
              <p className="text-[12px] font-semibold text-emerald-300">GPS obtenido</p>
              <p className="text-[11px] text-emerald-400/70 font-mono">{coords.lat.toFixed(5)}, {coords.lon.toFixed(5)}</p>
            </div>
          </div>
        )}

        {/* Feedback */}
        {status === 'ok' && (
          <DarkAlert icon={<CheckCircle size={17} className="text-emerald-400" />}
            title="¡Reporte enviado!" msg="Apareces en el mapa de otros usuarios." color="emerald" />
        )}
        {status === 'ratelimit' && (
          <DarkAlert icon={<XCircle size={17} className="text-amber-400" />}
            title="Demasiado rápido" msg="Puedes reportar una vez cada 10 segundos." color="amber" />
        )}
        {status === 'error' && (
          <DarkAlert icon={<XCircle size={17} className="text-red-400" />}
            title="No se pudo enviar" msg={errorMsg} color="red" />
        )}

        {/* CTA */}
        <button
          onClick={handleSubmit}
          disabled={!ruta || busy}
          className={`w-full py-4 rounded-2xl font-bold text-[15px] flex items-center justify-center gap-2.5 transition-all ${
            !ruta || busy
              ? 'bg-white/8 border border-white/10 text-slate-500 cursor-not-allowed'
              : 'bg-indigo-600 text-white shadow-lg shadow-indigo-900/50 active:scale-[0.98] active:brightness-90 hover:bg-indigo-500'
          }`}
        >
          {status === 'locating' && <><Loader2 size={18} className="animate-spin" />Obteniendo GPS…</>}
          {status === 'sending'  && <><Loader2 size={18} className="animate-spin" />Enviando…</>}
          {!['locating','sending'].includes(status) && cooldown > 0 && <>Próximo reporte en {cooldown}s</>}
          {!['locating','sending'].includes(status) && cooldown === 0 && <><Navigation size={18} />Reportar mi ubicación</>}
        </button>

        {/* Cómo funciona */}
        <div className="bg-white/5 border border-white/10 rounded-2xl overflow-hidden">
          <div className="px-4 py-3 border-b border-white/8">
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-widest">Cómo funciona</p>
          </div>
          {[
            'El app obtiene tu coordenada GPS',
            'Tu ID se anonimiza con SHA-256 en el servidor',
            'Apareces en el mapa para otros usuarios',
            'Tus datos se eliminan en 2 minutos',
          ].map((text, i, arr) => (
            <div key={i} className={`flex items-center gap-3.5 px-4 py-3 ${i < arr.length - 1 ? 'border-b border-white/8' : ''}`}>
              <span className="w-5 h-5 rounded-full bg-indigo-600 text-white text-[10px] font-extrabold flex items-center justify-center flex-shrink-0">
                {i + 1}
              </span>
              <span className="text-[13px] text-slate-300">{text}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function DarkAlert({ icon, title, msg, color }: {
  icon: React.ReactNode; title: string; msg: string
  color: 'emerald' | 'amber' | 'red'
}) {
  const cls = {
    emerald: { wrap: 'bg-emerald-500/15 border-emerald-500/25', t: 'text-emerald-300', s: 'text-emerald-400/70' },
    amber:   { wrap: 'bg-amber-500/15   border-amber-500/25',   t: 'text-amber-300',   s: 'text-amber-400/70'   },
    red:     { wrap: 'bg-red-500/15     border-red-500/25',     t: 'text-red-300',     s: 'text-red-400/70'     },
  }[color]
  return (
    <div className={`flex items-start gap-3 border rounded-xl p-3.5 ${cls.wrap}`}>
      <div className="flex-shrink-0 mt-0.5">{icon}</div>
      <div>
        <p className={`text-[13px] font-semibold ${cls.t}`}>{title}</p>
        <p className={`text-[12px] mt-px ${cls.s}`}>{msg}</p>
      </div>
    </div>
  )
}
