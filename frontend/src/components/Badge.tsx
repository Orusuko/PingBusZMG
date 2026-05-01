interface Props {
  tipo: string
}

const map: Record<string, { bg: string; text: string; dot: string; label: string }> = {
  tren_ligero:  { bg: 'bg-violet-500/20', text: 'text-violet-300', dot: 'bg-violet-400', label: 'Tren Ligero' },
  autobus:      { bg: 'bg-amber-500/20',  text: 'text-amber-300',  dot: 'bg-amber-400',  label: 'Autobús'     },
  alimentador:  { bg: 'bg-sky-500/20',    text: 'text-sky-300',    dot: 'bg-sky-400',    label: 'Alimentador' },
  BRT:          { bg: 'bg-rose-500/20',   text: 'text-rose-300',   dot: 'bg-rose-400',   label: 'BRT'         },
}

export default function Badge({ tipo }: Props) {
  const s = map[tipo] ?? { bg: 'bg-white/10', text: 'text-slate-300', dot: 'bg-slate-400', label: tipo }
  return (
    <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-semibold border border-white/10 ${s.bg} ${s.text}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${s.dot}`} />
      {s.label}
    </span>
  )
}
