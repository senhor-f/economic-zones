import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@economic-zone/checkout': resolve(__dirname, '../../pkg/checkout/src')
    }
  }
});
