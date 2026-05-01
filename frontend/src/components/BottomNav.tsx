import { MapPin, Radio } from 'lucide-react'

type Tab = 'inicio' | 'reportar'

interface Props {
  active: Tab
  onChange: (tab: Tab) => void
}

const tabs = [
  { id: 'inicio'   as Tab, label: 'Rutas',    icon: MapPin },
  { id: 'reportar' as Tab, label: 'Reportar', icon: Radio  },
]

export default function BottomNav({ active, onChange }: Props) {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-slate-900/95 backdrop-blur-md border-t border-white/10">
      <div
        className="max-w-[430px] mx-auto flex"
        style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
      >
        {tabs.map(({ id, label, icon: Icon }) => {
          const on = active === id
          return (
            <button
              key={id}
              onClick={() => onChange(id)}
              className="flex-1 flex flex-col items-center justify-center gap-1 py-3 relative transition-colors"
            >
              {on && (
                <span className="absolute inset-x-6 top-0 h-[2px] bg-indigo-400 rounded-b-full" />
              )}
              <div className={`w-10 h-10 flex items-center justify-center rounded-xl transition-colors ${on ? 'bg-indigo-500/20' : ''}`}>
                <Icon size={21} strokeWidth={on ? 2.2 : 1.6} className={on ? 'text-indigo-400' : 'text-slate-500'} />
              </div>
              <span className={`text-[11px] font-semibold tracking-wide ${on ? 'text-indigo-400' : 'text-slate-500'}`}>
                {label}
              </span>
            </button>
          )
        })}
      </div>
    </nav>
  )
}
