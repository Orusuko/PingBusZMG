import { ArrowLeft } from 'lucide-react'

interface Props {
  title: string
  subtitle?: string
  onBack?: () => void
  right?: React.ReactNode
}

export default function TopBar({ title, subtitle, onBack, right }: Props) {
  return (
    <header className="sticky top-0 z-40 bg-slate-900/95 backdrop-blur-md border-b border-white/10 px-4 py-3">
      <div className="max-w-[430px] mx-auto flex items-center gap-3 h-10">
        {onBack && (
          <button
            onClick={onBack}
            className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-white/10 active:bg-white/15 transition-colors flex-shrink-0 -ml-1"
          >
            <ArrowLeft size={19} className="text-white" />
          </button>
        )}
        <div className="flex-1 min-w-0">
          <h1 className="text-[15px] font-semibold text-white leading-tight truncate">{title}</h1>
          {subtitle && (
            <p className="text-[12px] text-slate-400 leading-tight truncate mt-px">{subtitle}</p>
          )}
        </div>
        {right && <div className="flex-shrink-0">{right}</div>}
      </div>
    </header>
  )
}
