import type { Metadata } from 'next'
import '@picocss/pico/css/pico.min.css'
import './globals.css'
import { Providers } from './providers'

export const metadata: Metadata = {
  title: 'On-Behalf-Of Demo',
  description: 'Demonstration of OAuth2 on-behalf-of flow with consent management',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" data-theme="dark">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}