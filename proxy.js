export const proxy = {
    target: 'http://localhost:10086', // Target server
    changeOrigin: true,              // Needed for virtual hosted sites
    rewrite: (path) => path.replace(/^\/api/, ''), // Rewrite the path (optional)
  };