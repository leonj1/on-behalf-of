/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  allowedDevOrigins: [
    'consent.joseserver.com',
    'https://consent.joseserver.com',
    'localhost:3000',
    'localhost:3005'
  ]
}

module.exports = nextConfig