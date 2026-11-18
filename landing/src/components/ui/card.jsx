import { cva } from 'class-variance-authority'
import { cn } from '../../lib/utils'

const cardVariants = cva('rounded-lg border-[3px] border-ink p-6 shadow-brutal transition-transform', {
  variants: {
    tone: {
      white: 'bg-white',
      sun: 'bg-sun',
      mint: 'bg-mint',
      pink: 'bg-pink',
      paper: 'bg-paper',
    },
    hover: { true: 'hover:-translate-y-1 hover:-rotate-[0.6deg]', false: '' },
  },
  defaultVariants: { tone: 'white', hover: true },
})

export function Card({ className, tone, hover, ...props }) {
  return <div className={cn(cardVariants({ tone, hover }), className)} {...props} />
}
