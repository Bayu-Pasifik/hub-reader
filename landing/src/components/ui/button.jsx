import { cva } from 'class-variance-authority'
import { cn } from '../../lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md border-[3px] border-ink font-bold transition-all ' +
    'shadow-brutal hover:translate-x-[3px] hover:translate-y-[3px] hover:shadow-none ' +
    'active:translate-x-[5px] active:translate-y-[5px] focus-visible:outline-4 focus-visible:outline-offset-2 focus-visible:outline-berry',
  {
    variants: {
      variant: {
        default: 'bg-sun text-ink',
        mint: 'bg-mint text-ink',
        pink: 'bg-pink text-ink',
        dark: 'bg-ink text-paper shadow-[5px_5px_0_0_#ff8fb1]',
        outline: 'bg-white text-ink',
      },
      size: {
        sm: 'h-10 px-4 text-sm',
        default: 'h-12 px-6 text-base',
        lg: 'h-14 px-8 text-lg',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

export function Button({ className, variant, size, href, ...props }) {
  const Comp = href ? 'a' : 'button'
  return <Comp href={href} className={cn(buttonVariants({ variant, size }), className)} {...props} />
}
