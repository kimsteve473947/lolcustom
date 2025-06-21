'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "94e90866a66e2d60305849007da17626",
"version.json": "17ded3f61bad4a790381c0efd1c5d9d9",
"index.html": "18d4ed4e8b7307ba9283d6edb69a0c0f",
"/": "18d4ed4e8b7307ba9283d6edb69a0c0f",
"main.dart.js": "df21475faf77616198f5ecaab51b21b3",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"favicon.png": "c194e2565a46d7dfdf7d05fc12063ab2",
"icons/Icon-192.png": "637dbc2f407a4944e444e497b220a58d",
"icons/Icon-maskable-192.png": "f941fc52b78c6b740794e50006b126ad",
"icons/Icon-maskable-512.png": "26df547442be36a7868d668ed29b9b0b",
"icons/Icon-512.png": "767c1cea61f28fff7534bbe52f779053",
"manifest.json": "820826569ad516acee91fc1f273bf67f",
"init_firebase_web.js": "c0178dd5b0db86a95122531ee5dc585c",
"assets/AssetManifest.json": "b668319a40a1346574a5db968b468380",
"assets/NOTICES": "162bd86747bf606b967c3af67a838c5a",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "84ea9d3aa8ba25a5aaca6d728eb49195",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "3288521c7e4cec8ee0e4bdfaec9659f7",
"assets/fonts/MaterialIcons-Regular.otf": "6fe18fdced0a06660ffa5f2ff4afc17a",
"assets/assets/images/lanes/lane_adc.png": "5ec8e2cd42ca2d15333317c501f926a9",
"assets/assets/images/lanes/lane_top.png": "04a9093e51b23bb6eb282e2b9784d6e3",
"assets/assets/images/lanes/lane_jungle.png": "c63db8d3e03ed61682362edec5ac17b0",
"assets/assets/images/lanes/lane_mid.png": "da2054a4b99d99859777b0cc24f9e888",
"assets/assets/images/lanes/lane_support.png": "3ec95017707483f0aa4fedfb2aceb612",
"assets/assets/images/tiers/%25EB%25A7%2588%25EC%258A%25A4%25ED%2584%25B0%25EB%25A1%259C%25EA%25B3%25A0.png": "2c7928aa6bc889ab75e261006b37cc36",
"assets/assets/images/tiers/%25EB%258B%25A4%25EC%259D%25B4%25EC%2595%2584%25EB%25A1%259C%25EA%25B3%25A0.png": "72ec52863276b772cd5dc6022988eb4b",
"assets/assets/images/tiers/%25EA%25B3%25A8%25EB%2593%259C%25EB%25A1%259C%25EA%25B3%25A0.png": "6d0f0788007223dcda835d122aded04c",
"assets/assets/images/tiers/%25EB%25B8%258C%25EB%25A1%25A0%25EC%25A6%2588%25EB%25A1%259C%25EA%25B3%25A0.png": "6a06989589040a97aa03f944999cd29c",
"assets/assets/images/tiers/%25EC%258B%25A4%25EB%25B2%2584%25EB%25A1%259C%25EA%25B3%25A0.png": "7b8133fa1c7655020015072dfa6423a5",
"assets/assets/images/tiers/%25EC%2597%2590%25EB%25A9%2594%25EB%259E%2584%25EB%2593%259C%25EB%25A1%259C%25EA%25B3%25A0.png": "998cb285e9b3f1c42c8068e1adb522a6",
"assets/assets/images/tiers/%25EC%2595%2584%25EC%259D%25B4%25EC%2596%25B8%25EB%25A1%259C%25EA%25B3%25A0.png": "436ccdab59e4f091b53b32d6fb5d8fb1",
"assets/assets/images/tiers/%25ED%2594%258C%25EB%25A0%2588%25ED%258B%25B0%25EB%2584%2598%25EB%25A1%259C%25EA%25B3%25A0.png": "fa3509f5d7d8d873a7ddfe9d197a0851",
"assets/assets/images/profile_placeholder.png": "7fef4250bc2e338f70a2834ab99f4d22",
"assets/assets/images/app_logo.png": "87e15b1ba0ce5a8485a7b5073860d13e",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
