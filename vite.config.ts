import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

function bustStaleBrowserCachePlugin() {
  return {
    name: 'bust-stale-browser-cache',
    enforce: 'post' as const,
    transform(code: string, id: string) {
      if (id.includes('/src/') && /\.(tsx?|jsx?)$/.test(id)) {
        return code.replace(
          /from\s+(['"])(\/src\/[^'"?]+)\1/g,
          'from $1$2?v=2414$1'
        );
      }
      return null;
    },
  };
}

export default defineConfig({
  cacheDir: 'node_modules/.vite-v240',
  plugins: [react(), tailwindcss(), bustStaleBrowserCachePlugin()],
  resolve: {
    dedupe: ['react', 'react-dom', 'react/jsx-runtime', 'react/jsx-dev-runtime'],
  },
  optimizeDeps: {
    include: [
      'react',
      'react-dom',
      'react-dom/client',
      'react/jsx-runtime',
      'react/jsx-dev-runtime',
      'lucide-react',
      'firebase/app',
      'firebase/auth',
      'firebase/firestore',
    ],
  },
  server: {
    port: 3000,
    host: '0.0.0.0',
    hmr: false,
    ws: false,
  },
});



