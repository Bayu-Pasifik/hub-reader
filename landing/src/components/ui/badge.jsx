import { cva } from 'class-variance-authority'
import { cn } from '../../lib/utils'

const badgeVariants = cva(
  'inline-flex items-center gap-1.5 rounded-full border-[2.5px] border-ink px-3 py-1 font-mono text-xs font-bold uppercase tracking-wide',
  {
    variants: {
      tone: { sun: 'bg-sun', mint: 'bg-mint', pink: 'bg-pink', white: 'bg-white', dark: 'bg-ink text-paper' },
    },
    defaultVariants: { tone: 'white' },
  },
)

export function Badge({ className, tone, ...props }) {
  return <span className={cn(badgeVariants({ tone }), className)} {...props} />
}
