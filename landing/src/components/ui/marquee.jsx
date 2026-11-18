import { cn } from '../../lib/utils'

export function Marquee({ items, className }) {
  const row = [...items, ...items]
  return (
    <div className={cn('overflow-hidden border-y-[3px] border-ink bg-ink py-3', className)}>
      <div className="flex w-max animate-marquee gap-8 text-paper" aria-hidden="true">
        {row.map((t, i) => (
          <span key={i} className="flex items-center gap-8 font-mono text-lg font-bold uppercase">
            {t}
            <span className="text-sun">✱</span>
          </span>
        ))}
      </div>
    </div>
  )
}
