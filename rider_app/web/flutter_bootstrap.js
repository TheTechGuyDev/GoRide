{{flutter_js}}
{{flutter_build_config}}

// Render Flutter inside #app (sized to the visible screen) instead of the
// whole page, then fade out the loading screen.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.querySelector('#app'),
    });
    await appRunner.runApp();
    const loading = document.getElementById('loading');
    if (loading) {
      loading.style.opacity = '0';
      setTimeout(function () { loading.remove(); }, 350);
    }
  },
});
