import { useState } from 'react'
import { Plus } from 'lucide-react'
import { cn } from '../../lib/utils'

export function Accordion({ items }) {
  const [open, setOpen] = useState(0)
  return (
    <div className="space-y-4">
      {items.map((it, i) => {
        const isOpen = open === i
        return (
          <div key={it.q} className={cn('rounded-lg border-[3px] border-ink shadow-brutal', isOpen ? 'bg-sun' : 'bg-white')}>
            <button
              className="flex w-full items-center justify-between gap-4 p-5 text-left text-lg font-bold"
              aria-expanded={isOpen}
              onClick={() => setOpen(isOpen ? -1 : i)}
            >
              {it.q}
              <Plus className={cn('size-6 shrink-0 transition-transform', isOpen && 'rotate-45')} strokeWidth={3} />
            </button>
            {isOpen && <p className="border-t-[3px] border-ink p-5 leading-relaxed">{it.a}</p>}
          </div>
        )
      })}
    </div>
  )
}
