package com.dkmads.ssp

/**
 * MRAID 2.0 bridge JavaScript, mirrored from `sdk/shared/mraid/mraid.js`
 * (canonical source). Embedded as a string so it can be injected into the
 * creative WebView without shipping a separate asset.
 *
 * Keep this in sync with the shared file when the MRAID bridge changes.
 */
internal object DKMadsMraidScript {
    const val JS: String = """
(function () {
  if (window.mraid) return;

  var STATES = { LOADING: 'loading', DEFAULT: 'default', EXPANDED: 'expanded', RESIZED: 'resized', HIDDEN: 'hidden' };
  var EVENTS = { READY: 'ready', ERROR: 'error', STATE_CHANGE: 'stateChange', VIEWABLE_CHANGE: 'viewableChange', SIZE_CHANGE: 'sizeChange' };

  var listeners = {};
  var state = STATES.LOADING;
  var viewable = false;
  var placementType = 'inline';
  var isReady = false;
  var customClose = false;

  var geometry = {
    currentPosition: { x: 0, y: 0, width: 0, height: 0 },
    defaultPosition: { x: 0, y: 0, width: 0, height: 0 },
    maxSize: { width: 0, height: 0 },
    screenSize: { width: 0, height: 0 },
  };

  var expandProperties = { width: 0, height: 0, useCustomClose: false, isModal: true };
  var orientationProperties = { allowOrientationChange: true, forceOrientation: 'none' };
  var supports = { sms: false, tel: false, calendar: false, storePicture: false, inlineVideo: true, vpaid: false, location: false };

  function fire(event) {
    var args = Array.prototype.slice.call(arguments, 1);
    (listeners[event] || []).slice().forEach(function (cb) {
      try { cb.apply(null, args); } catch (e) {}
    });
  }

  function sendCommand(command, payload) {
    var msg = { command: command, payload: payload || {} };
    try {
      if (window.DKMadsMraidNative && typeof window.DKMadsMraidNative.postMessage === 'function') {
        window.DKMadsMraidNative.postMessage(JSON.stringify(msg));
        return;
      }
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dkmadsMraid) {
        window.webkit.messageHandlers.dkmadsMraid.postMessage(msg);
      }
    } catch (e) {}
  }

  function setState(next) {
    if (state === next) return;
    state = next;
    fire(EVENTS.STATE_CHANGE, state);
  }

  var mraid = {
    getVersion: function () { return '2.0'; },
    getState: function () { return state; },
    getPlacementType: function () { return placementType; },
    isViewable: function () { return viewable; },

    addEventListener: function (event, listener) {
      if (!event || typeof listener !== 'function') return;
      (listeners[event] = listeners[event] || []).push(listener);
    },
    removeEventListener: function (event, listener) {
      if (!listeners[event]) return;
      if (!listener) { delete listeners[event]; return; }
      listeners[event] = listeners[event].filter(function (cb) { return cb !== listener; });
    },

    open: function (url) {
      if (!url) { fire(EVENTS.ERROR, 'open requires a url', 'open'); return; }
      sendCommand('open', { url: String(url) });
    },
    close: function () { sendCommand('close'); },
    expand: function (url) {
      if (placementType === 'interstitial') return;
      sendCommand('expand', { url: url ? String(url) : null, properties: expandProperties });
    },
    resize: function () {
      if (!expandProperties.width || !expandProperties.height) {
        fire(EVENTS.ERROR, 'resize requires resizeProperties', 'resize');
        return;
      }
      sendCommand('resize', { properties: expandProperties });
    },
    useCustomClose: function (flag) {
      customClose = Boolean(flag);
      expandProperties.useCustomClose = customClose;
      sendCommand('useCustomClose', { useCustomClose: customClose });
    },
    playVideo: function (url) { sendCommand('playVideo', { url: String(url || '') }); },

    getCurrentPosition: function () { return geometry.currentPosition; },
    getDefaultPosition: function () { return geometry.defaultPosition; },
    getMaxSize: function () { return geometry.maxSize; },
    getScreenSize: function () { return geometry.screenSize; },

    getExpandProperties: function () { return expandProperties; },
    setExpandProperties: function (props) { expandProperties = Object.assign({}, expandProperties, props || {}); },
    getOrientationProperties: function () { return orientationProperties; },
    setOrientationProperties: function (props) { orientationProperties = Object.assign({}, orientationProperties, props || {}); },
    getResizeProperties: function () { return expandProperties; },
    setResizeProperties: function (props) { expandProperties = Object.assign({}, expandProperties, props || {}); },

    supports: function (feature) { return Boolean(supports[feature]); },

    _dkmadsSetReady: function (type, geo) {
      if (isReady) return;
      placementType = type || 'inline';
      if (geo) mraid._dkmadsSetGeometry(geo);
      isReady = true;
      setState(STATES.DEFAULT);
      fire(EVENTS.READY);
    },
    _dkmadsSetViewable: function (next) {
      var v = Boolean(next);
      if (v === viewable) return;
      viewable = v;
      fire(EVENTS.VIEWABLE_CHANGE, viewable);
    },
    _dkmadsSetState: function (next) { setState(next); },
    _dkmadsSetGeometry: function (geo) {
      if (!geo) return;
      if (geo.currentPosition) geometry.currentPosition = geo.currentPosition;
      if (geo.defaultPosition) geometry.defaultPosition = geo.defaultPosition;
      if (geo.maxSize) geometry.maxSize = geo.maxSize;
      if (geo.screenSize) geometry.screenSize = geo.screenSize;
      if (geo.currentPosition) {
        fire(EVENTS.SIZE_CHANGE, geo.currentPosition.width, geo.currentPosition.height);
      }
    },
    _dkmadsSetSupports: function (map) { supports = Object.assign({}, supports, map || {}); },
    _dkmadsError: function (message, action) { fire(EVENTS.ERROR, message, action); },
  };

  window.mraid = mraid;
})();
"""
}
