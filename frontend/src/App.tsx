import { useState, useEffect } from 'react'
import BottomNav from './components/BottomNav'
import Inicio from './pages/Inicio'
import DetalleRuta from './pages/DetalleRuta'
import Reportar from './pages/Reportar'
import Estadisticas from './pages/Estadisticas'

type Tab = 'inicio' | 'reportar'

export default function App() {
  const [tab, setTab]                     = useState<Tab>('inicio')
  const [rutaSeleccionada, setRutaSeleccionada] = useState<string | null>(null)
  const [showSistema, setShowSistema]     = useState(false)

  // Hash routing: #sistema abre el dashboard de sistema
  useEffect(() => {
    const check = () => setShowSistema(window.location.hash === '#sistema')
    check()
    window.addEventListener('hashchange', check)
    return () => window.removeEventListener('hashchange', check)
  }, [])

  if (showSistema) return <Estadisticas />

  return (
    <div className="min-h-screen bg-slate-900">
      <main className="max-w-[430px] mx-auto relative">
        {tab === 'inicio' && !rutaSeleccionada && (
          <Inicio onSelectRuta={setRutaSeleccionada} />
        )}
        {tab === 'inicio' && rutaSeleccionada && (
          <DetalleRuta clave={rutaSeleccionada} onBack={() => setRutaSeleccionada(null)} />
        )}
        {tab === 'reportar' && <Reportar />}
      </main>

      {!(tab === 'inicio' && rutaSeleccionada) && (
        <BottomNav
          active={tab}
          onChange={t => { setTab(t); setRutaSeleccionada(null) }}
        />
      )}
    </div>
  )
}
