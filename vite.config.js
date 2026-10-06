import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Relative asset paths, so the built site works both at
// rockindash.github.io/DockorateWebsite/ and on a custom domain.
export default defineConfig({
  base: './',
  plugins: [react()],
})
