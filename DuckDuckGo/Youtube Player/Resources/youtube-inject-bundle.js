"use strict";
(() => {
  var __defProp = Object.defineProperty;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __publicField = (obj, key, value) => {
    __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
    return value;
  };

  // assets/styles.css
  var styles_default = '/* -- THUMBNAIL OVERLAY -- */\n.ddg-overlay {\n    font-family: system, -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";\n    position: absolute;\n    margin-top: 5px;\n    margin-left: 5px;\n    z-index: 1000;\n    height: 32px;\n\n    background: rgba(0, 0, 0, 0.6);\n    box-shadow: 0px 1px 2px rgba(0, 0, 0, 0.25), 0px 4px 8px rgba(0, 0, 0, 0.1), inset 0px 0px 0px 1px rgba(0, 0, 0, 0.18);\n    backdrop-filter: blur(2px);\n    -webkit-backdrop-filter: blur(2px);\n    border-radius: 6px;\n\n    transition: 0.15s linear background;\n}\n\n.ddg-overlay a.ddg-play-privately {\n    color: white;\n    text-decoration: none;\n    font-style: normal;\n    font-weight: 600;\n    font-size: 12px;\n}\n\n.ddg-overlay .ddg-dax,\n.ddg-overlay .ddg-play-icon {\n    display: inline-block;\n\n}\n\n.ddg-overlay .ddg-dax {\n    float: left;\n    padding: 4px 4px;\n    width: 24px;\n    height: 24px;\n}\n\n.ddg-overlay .ddg-play-text-container {\n    width: 0px;\n    overflow: hidden;\n    float: left;\n    opacity: 0;\n    transition: all 0.15s linear;\n}\n\n.ddg-overlay .ddg-play-text {\n    line-height: 14px;\n    margin-top: 10px;\n    width: 200px;\n}\n\n.ddg-overlay .ddg-play-icon {\n    float: right;\n    width: 24px;\n    height: 20px;\n    padding: 6px 4px;\n}\n\n.ddg-overlay:not([data-size="fixed small"]):hover .ddg-play-text-container {\n    width: 80px;\n    opacity: 1;\n}\n\n.ddg-overlay[data-size^="video-player"].hidden {\n    display: none;\n}\n\n.ddg-overlay[data-size="video-player"] {\n    bottom: 145px;\n    right: 20px;\n    opacity: 1;\n    transition: opacity .2s;\n}\n\n.html5-video-player.playing-mode.ytp-autohide .ddg-overlay[data-size="video-player"] {\n    opacity: 0;\n}\n\n.html5-video-player.ad-showing .ddg-overlay[data-size="video-player"] {\n    display: none;\n}\n\n.html5-video-player.ytp-hide-controls .ddg-overlay[data-size="video-player"] {\n    display: none;\n}\n\n.ddg-overlay[data-size="video-player-with-title"] {\n    top: 40px;\n    left: 10px;\n}\n\n.ddg-overlay[data-size="video-player-with-paid-content"] {\n    top: 65px;\n    left: 11px;\n}\n\n.ddg-overlay[data-size="title"] {\n    position: relative;\n    margin: 0;\n    float: right;\n}\n\n.ddg-overlay[data-size="title"] .ddg-play-text-container {\n    width: 90px;\n}\n\n.ddg-overlay[data-size^="fixed"] {\n    position: absolute;\n    top: 0;\n    left: 0;\n    display: none;\n    z-index: 10;\n}\n\n#preview .ddg-overlay {\n    transition: transform 160ms ease-out 200ms;\n    /*TODO: scale needs to equal 1/--ytd-video-preview-initial-scale*/\n    transform: scale(1.15) translate(5px, 4px);\n}\n\n#preview ytd-video-preview[active] .ddg-overlay {\n    transform:scale(1) translate(0px, 0px);\n}\n';

  // src/util.js
  function addTrustedEventListener(element, event, callback) {
    element.addEventListener(event, (e) => {
      if (e.isTrusted) {
        callback(e);
      }
    });
  }
  function onDOMLoaded(callback) {
    window.addEventListener("DOMContentLoaded", () => {
      callback();
    });
  }
  function onDOMChanged(callback) {
    let observer = new MutationObserver(callback);
    observer.observe(document.body, {
      subtree: true,
      childList: true,
      attributeFilter: ["src"]
    });
  }
  function appendElement(to, element) {
    to.appendChild(element);
  }
  function appendImageAsBackground(parent, targetSelector, imageUrl) {
    let canceled = false;
    fetch(imageUrl, { method: "HEAD" }).then((x) => {
      const status = String(x.status);
      if (canceled)
        return console.warn("not adding image, cancelled");
      if (status.startsWith("2")) {
        if (!canceled) {
          append();
        } else {
          console.warn("ignoring cancelled load");
        }
      } else {
        console.error("\u274C status code did not start with a 2");
        markError();
      }
    }).catch((x) => {
      console.error("e from fetch");
    });
    function markError() {
      parent.dataset.thumbLoaded = String(false);
      parent.dataset.error = String(true);
    }
    function append() {
      const targetElement = parent.querySelector(targetSelector);
      if (!(targetElement instanceof HTMLElement))
        return console.warn("could not find child with selector", targetSelector, "from", parent);
      parent.dataset.thumbLoaded = String(true);
      parent.dataset.thumbSrc = imageUrl;
      let img = new Image();
      img.src = imageUrl;
      img.onload = function(arg) {
        if (canceled)
          return console.warn("not adding image, cancelled");
        targetElement.style.backgroundImage = `url(${imageUrl})`;
        targetElement.style.backgroundSize = `cover`;
      };
      img.onerror = function(arg) {
        if (canceled)
          return console.warn("not calling markError, cancelled");
        markError();
        const targetElement2 = parent.querySelector(targetSelector);
        if (!(targetElement2 instanceof HTMLElement))
          return;
        targetElement2.style.backgroundImage = ``;
      };
    }
  }
  function execCleanups(cleanups) {
    for (let cleanup of cleanups) {
      if (typeof cleanup.fn === "function") {
        try {
          cleanup.fn();
          console.log("\u{1F9F9} cleanup '%s' was successfully executed", cleanup.name);
        } catch (e) {
          console.error(`cleanup ${cleanup.name} threw`, e);
        }
      } else {
        throw new Error("invalid cleanup");
      }
    }
  }
  function applyEffect(name, fn, storage) {
    let cleanup;
    try {
      cleanup = fn();
      console.log(`\u2622\uFE0F side effect '%s' executed`, name);
    } catch (e) {
      console.error("%s threw an error", name, e);
    }
    if (typeof cleanup === "function") {
      storage.push({ name, fn: cleanup });
    }
  }
  var _VideoParams = class {
    constructor(id, time) {
      this.id = id;
      this.time = time;
    }
    toPrivatePlayerUrl() {
      const duckUrl = new URL(this.id, "https://player");
      duckUrl.protocol = "duck:";
      if (this.time) {
        duckUrl.searchParams.set("t", this.time);
      }
      return duckUrl.href;
    }
    static forWatchPage(href) {
      let url = new URL(href);
      if (!url.pathname.startsWith("/watch")) {
        return null;
      }
      return _VideoParams.fromHref(url.href);
    }
    static fromPathname(pathname) {
      let url = new URL(pathname, window.location.origin);
      return _VideoParams.fromHref(url.href);
    }
    static fromHref(href) {
      const url = new URL(href);
      const vParam = url.searchParams.get("v");
      const tParam = url.searchParams.get("t");
      let id = null;
      let time = null;
      if (vParam && _VideoParams.validVideoId.test(vParam)) {
        id = vParam;
      } else {
        return null;
      }
      if (tParam && _VideoParams.validTimestamp.test(tParam)) {
        time = tParam;
      }
      return new _VideoParams(id, time);
    }
  };
  var VideoParams = _VideoParams;
  __publicField(VideoParams, "validVideoId", /^[a-zA-Z0-9-_]+$/);
  __publicField(VideoParams, "validTimestamp", /^[0-9hms]+$/);

  // assets/dax.svg
  var dax_default = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">\n    <path d="M12 23C18.0751 23 23 18.0751 23 12C23 5.92487 18.0751 1 12 1C5.92487 1 1 5.92487 1 12C1 18.0751 5.92487 23 12 23Z" fill="#DE5833"/>\n    <path d="M14.1404 21.001C13.7872 20.3171 13.4179 19.3192 13.202 18.889C12.5118 17.4948 11.8167 15.5303 12.1324 14.2629C12.1896 14.0322 11.4814 5.73576 10.981 5.46712C10.4249 5.16882 9.21625 4.77493 8.58985 4.66945C8.15317 4.59859 8.05504 4.72219 7.87186 4.75021C8.04522 4.76834 8.86625 5.17541 9.02489 5.19848C8.86625 5.30726 8.39686 5.19519 8.09756 5.32868C7.94546 5.39955 7.83261 5.65994 7.83588 5.7819C8.69125 5.69455 10.0275 5.78025 10.819 6.13294C10.1894 6.20546 9.2326 6.28621 8.82209 6.50376C7.62817 7.13662 7.10154 8.61824 7.41555 10.3949C7.70667 12.0479 8.99561 18.4844 9.51734 21.001C10.4365 21.3174 11.1214 21.4768 12.1453 21.4768C13.1398 21.4768 13.5844 21.1081 14.1404 21.001Z" fill="#D5D7D8"/>\n    <path fill-rule="evenodd" clip-rule="evenodd" d="M9.98431 21.1699C9.80923 19.9162 9.49398 18.6007 9.23216 17.3624C8.65596 14.6372 7.93939 11.248 7.72236 10.0352C7.40449 8.25212 7.72236 6.97898 8.9359 6.33992C9.35145 6.12139 9.94414 5.96245 10.5799 5.89126C9.77859 5.53531 8.82828 5.3979 7.9591 5.48564C7.95693 5.2445 8.23556 5.17084 8.49618 5.10193C8.63279 5.06582 8.76446 5.03101 8.84815 4.97407C8.77135 4.96299 8.64002 4.87503 8.50451 4.78428C8.35667 4.68527 8.20384 4.58292 8.11142 4.57342C9.21403 4.38468 10.3481 4.56183 11.3381 5.08168C11.8431 5.3532 12.2007 5.64292 12.4209 5.9459C12.9954 6.05682 13.5036 6.26377 13.8364 6.59654C14.8579 7.61637 15.7685 9.94412 15.3877 11.2835C15.2801 11.6543 15.035 11.9258 14.7271 12.1493C14.49 12.3221 14.3637 12.2786 14.2048 12.2239C13.9631 12.1407 13.6463 12.0316 12.7503 12.6179C12.6178 12.7039 12.576 13.1735 12.5437 13.5358C12.5288 13.7031 12.5159 13.8476 12.497 13.9208C12.1792 15.194 12.8795 17.1658 13.5798 18.568C13.7139 18.8353 13.8898 19.1724 14.0885 19.5531C14.1984 19.7636 14.5199 20.5797 14.6405 20.8125C12.4209 21.639 12.1751 21.7333 9.98431 21.1699Z" fill="white"/>\n    <path d="M9.85711 10.5714C10.2516 10.5714 10.5714 10.2916 10.5714 9.94641C10.5714 9.60123 10.2516 9.32141 9.85711 9.32141C9.46262 9.32141 9.14282 9.60123 9.14282 9.94641C9.14282 10.2916 9.46262 10.5714 9.85711 10.5714Z" fill="#2D4F8E"/>\n    <path d="M10.1723 9.93979C10.2681 9.93979 10.3458 9.86211 10.3458 9.76628C10.3458 9.67046 10.2681 9.59277 10.1723 9.59277C10.0765 9.59277 9.99878 9.67046 9.99878 9.76628C9.99878 9.86211 10.0765 9.93979 10.1723 9.93979Z" fill="white"/>\n    <path d="M14.2664 10.3734C14.5539 10.3734 14.7869 10.1015 14.7869 9.7661C14.7869 9.43071 14.5539 9.15881 14.2664 9.15881C13.9789 9.15881 13.7458 9.43071 13.7458 9.7661C13.7458 10.1015 13.9789 10.3734 14.2664 10.3734Z" fill="#2D4F8E"/>\n    <path d="M14.469 9.67966C14.5489 9.67966 14.6137 9.60198 14.6137 9.50615C14.6137 9.41032 14.5489 9.33264 14.469 9.33264C14.389 9.33264 14.3242 9.41032 14.3242 9.50615C14.3242 9.60198 14.389 9.67966 14.469 9.67966Z" fill="white"/>\n    <path d="M9.9291 8.17747C9.9291 8.17747 9.46635 7.96895 9.01725 8.24947C8.56968 8.52849 8.58485 8.81201 8.58485 8.81201C8.58485 8.81201 8.34664 8.28697 8.98084 8.02896C9.61959 7.77394 9.9291 8.17747 9.9291 8.17747Z" fill="#2D4F8E"/>\n    <path d="M14.6137 8.07779C14.6137 8.07779 14.2487 7.93456 13.9655 7.93685C13.3839 7.94144 13.2256 8.1179 13.2256 8.1179C13.2256 8.1179 13.3239 7.69738 14.0671 7.78217C14.3087 7.81196 14.5137 7.92196 14.6137 8.07779Z" fill="#2D4F8E"/>\n    <path d="M12.0108 12.7346C12.0749 12.338 13.061 11.5901 13.7612 11.5432C14.4613 11.4979 14.6786 11.5092 15.2615 11.3635C15.846 11.2194 17.3526 10.831 17.7668 10.6319C18.1841 10.4327 19.9501 10.7306 18.7061 11.4509C18.1669 11.7633 16.715 12.3364 15.6772 12.6585C14.6411 12.979 14.0112 12.3509 13.6674 12.8803C13.3939 13.2995 13.6127 13.8742 14.8505 13.9939C16.5243 14.1542 18.1278 13.2137 18.3044 13.7139C18.481 14.2141 16.8681 14.8357 15.8835 14.8567C14.9005 14.8761 12.9188 14.1833 12.6234 13.9697C12.3249 13.756 11.9295 13.2542 12.0108 12.7346Z" fill="#FDD20A"/>\n    <path d="M15.438 16.6617C15.1403 16.5928 13.9974 17.4122 13.5492 17.7446C13.531 17.6708 13.5161 17.6103 13.5012 17.5767C13.4285 17.3937 12.3286 17.4978 12.0375 17.7749C11.3429 17.4239 9.91387 16.754 9.8841 17.1654C9.8411 17.7127 9.8841 19.9425 10.1735 20.112C10.3852 20.2363 11.5479 19.5966 12.1599 19.2423C12.1781 19.249 12.1946 19.2541 12.2161 19.2608C12.5883 19.3464 13.2928 19.2608 13.5426 19.0929C13.5674 19.0761 13.5872 19.0475 13.6021 19.014C14.1661 19.2356 15.3156 19.6621 15.562 19.5697C15.8928 19.4388 15.8101 16.7473 15.438 16.6617Z" fill="#65BC46"/>\n    <path d="M12.3032 19.1199C11.9194 19.0371 12.0491 18.6648 12.0491 17.7943L12.0474 17.7926C12.0474 17.791 12.0491 17.7877 12.0491 17.786C11.9484 17.8439 11.8836 17.9118 11.8836 17.9879H11.8853C11.8853 18.8584 11.7557 19.2324 12.1394 19.3151C12.5249 19.3979 13.2514 19.3151 13.509 19.1497C13.5516 19.1215 13.5806 19.0669 13.5994 18.9941C13.2992 19.1331 12.6562 19.1976 12.3032 19.1199Z" fill="#43A244"/>\n    <path fill-rule="evenodd" clip-rule="evenodd" d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22ZM12 21C16.9706 21 21 16.9706 21 12C21 7.02944 16.9706 3 12 3C7.02944 3 3 7.02944 3 12C3 16.9706 7.02944 21 12 21Z" fill="white"/>\n</svg>';

  // src/text.js
  var text = {
    "playText": {
      "title": "Duck Player"
    },
    "videoOverlayTitle": {
      "title": "Tired of targeted YouTube ads and recommendations?"
    },
    "videoOverlaySubtitle": {
      "title": "<b>Duck Player</b> provides a clean viewing experience without personalized ads and prevents viewing activity from influencing your YouTube recommendations."
    },
    "videoButtonOpen": {
      "title": "Watch in Duck Player"
    },
    "videoButtonOptOut": {
      "title": "Watch Here"
    },
    "rememberLabel": {
      "title": "Remember my choice"
    }
  };
  var i18n = {
    t(name) {
      if (!text.hasOwnProperty(name)) {
        console.error(`missing key ${name}`);
        return "missing";
      }
      const match = text[name];
      if (!match.title) {
        return "missing";
      }
      return match.title;
    }
  };

  // src/comms.js
  var macOSCommunications = {
    setUserValues(userValues) {
      console.log("\u{1F4E4} [outgoing]", userValues);
      let resp = window.webkit?.messageHandlers?.setUserValues?.postMessage(userValues);
      if (resp instanceof Promise) {
        return resp.then((x) => JSON.parse(x)).catch((e) => console.error("could not call setInteracted", e));
      }
      return Promise.reject(resp);
    },
    readUserValues() {
      let resp = window.webkit?.messageHandlers?.readUserValues?.postMessage({});
      if (resp instanceof Promise) {
        return resp.then((x) => JSON.parse(x)).catch((e) => console.error("could not call readUserValues", e));
      }
      return Promise.reject(resp);
    },
    openInDuckPlayerViaMessage(href) {
      window.webkit?.messageHandlers?.openDuckPlayer?.postMessage(href);
      console.log("\u{1F4E4} [outgoing]", 'openDuckPlayer.postMessage("' + href + '")');
    },
    onUserValuesNotification(cb) {
      window.onUserValuesChanged = function(values) {
        if (!values?.userValuesNotification) {
          console.error("missing userValuesNotification");
          return;
        }
        cb(values.userValuesNotification);
      };
    }
  };

  // src/icon-overlay.js
  var IconOverlay = {
    HOVER_CLASS: "ddg-overlay-hover",
    OVERLAY_CLASS: "ddg-overlay",
    currentVideoElement: null,
    hoverOverlayVisible: false,
    create: (size, href, extraClass) => {
      let overlayElement = document.createElement("div");
      overlayElement.setAttribute("class", "ddg-overlay" + (extraClass ? " " + extraClass : ""));
      overlayElement.setAttribute("data-size", size);
      overlayElement.innerHTML = `
                <a class="ddg-play-privately" href="#">
                    <div class="ddg-dax">
                        ${dax_default}
                    </div>
                    <div class="ddg-play-text-container">
                        <div class="ddg-play-text">
                            ${i18n.t("playText")}
                        </div>
                    </div>
                </a>`;
      overlayElement.querySelector("a.ddg-play-privately")?.setAttribute("href", href);
      overlayElement.querySelector("a.ddg-play-privately").addEventListener("click", (event, a, b) => {
        event.preventDefault();
        event.stopPropagation();
        let link = event.target.closest("a");
        let href2 = link.getAttribute("href");
        macOSCommunications.openInDuckPlayerViaMessage(href2);
        return;
      });
      return overlayElement;
    },
    getHoverOverlay: () => {
      return document.querySelector("." + IconOverlay.HOVER_CLASS);
    },
    moveHoverOverlayToVideoElement: (videoElement) => {
      let overlay = IconOverlay.getHoverOverlay();
      if (overlay === null) {
        return;
      }
      let videoElementOffset = IconOverlay.getElementOffset(videoElement);
      overlay.setAttribute(
        "style",
        "top: " + videoElementOffset.top + "px;left: " + videoElementOffset.left + "px;display:block;"
      );
      overlay.setAttribute("data-size", "fixed " + IconOverlay.getThumbnailSize(videoElement));
      const href = videoElement.getAttribute("href");
      if (href) {
        const privateUrl = VideoParams.fromPathname(href)?.toPrivatePlayerUrl();
        if (overlay && privateUrl) {
          overlay.querySelector("a")?.setAttribute("href", privateUrl);
        }
      }
      IconOverlay.hoverOverlayVisible = true;
      IconOverlay.currentVideoElement = videoElement;
    },
    getElementOffset: (el) => {
      const box = el.getBoundingClientRect();
      const docElem = document.documentElement;
      return {
        top: box.top + window.pageYOffset - docElem.clientTop,
        left: box.left + window.pageXOffset - docElem.clientLeft
      };
    },
    repositionHoverOverlay: () => {
      if (IconOverlay.currentVideoElement && IconOverlay.hoverOverlayVisible) {
        IconOverlay.moveHoverOverlayToVideoElement(IconOverlay.currentVideoElement);
      }
    },
    hideHoverOverlay: (event, force) => {
      let overlay = IconOverlay.getHoverOverlay();
      let toElement = event.toElement;
      if (overlay) {
        if (toElement === overlay || overlay.contains(toElement) || force) {
          return;
        }
        IconOverlay.hideOverlay(overlay);
        IconOverlay.hoverOverlayVisible = false;
      }
    },
    hideOverlay: (overlay) => {
      overlay.setAttribute("style", "display:none;");
    },
    appendHoverOverlay: () => {
      let el = IconOverlay.create("fixed", "", IconOverlay.HOVER_CLASS);
      appendElement(document.body, el);
      addTrustedEventListener(document.body, "mouseup", (event) => {
        IconOverlay.hideHoverOverlay(event);
      });
    },
    appendToVideo: (videoElement) => {
      let appendOverlayToThumbnail = (videoElement2) => {
        if (videoElement2) {
          const privateUrl = VideoParams.fromHref(videoElement2.href)?.toPrivatePlayerUrl();
          const thumbSize = IconOverlay.getThumbnailSize(videoElement2);
          if (privateUrl) {
            appendElement(videoElement2, IconOverlay.create(thumbSize, privateUrl));
            videoElement2.classList.add("has-dgg-overlay");
          }
        }
      };
      let videoElementAlreadyHasOverlay = videoElement && videoElement.querySelector('div[class="ddg-overlay"]');
      if (!videoElementAlreadyHasOverlay) {
        appendOverlayToThumbnail(videoElement);
        return true;
      }
      return false;
    },
    getThumbnailSize: (videoElement) => {
      let imagesByArea = {};
      Array.from(videoElement.querySelectorAll("img")).forEach((image) => {
        imagesByArea[image.offsetWidth * image.offsetHeight] = image;
      });
      let largestImage = Math.max.apply(void 0, Object.keys(imagesByArea).map(Number));
      let getSizeType = (width, height) => {
        if (width < 123 + 10) {
          return "small";
        } else if (width < 300 && height < 175) {
          return "medium";
        } else {
          return "large";
        }
      };
      return getSizeType(imagesByArea[largestImage].offsetWidth, imagesByArea[largestImage].offsetHeight);
    },
    removeAll: () => {
      document.querySelectorAll("." + IconOverlay.OVERLAY_CLASS).forEach((element) => {
        element.remove();
      });
    }
  };

  // src/video-player-icon.js
  var VideoPlayerIcon = class {
    constructor() {
      __publicField(this, "_cleanups", []);
    }
    init(containerElement, params) {
      if (!containerElement) {
        console.error("missing container element");
        return;
      }
      this.appendOverlay(containerElement, params);
    }
    appendOverlay(containerElement, params) {
      this.cleanup();
      const href = params.toPrivatePlayerUrl();
      const iconElement = IconOverlay.create("video-player", href, "hidden");
      this.sideEffect("dax \u{1F425} icon overlay", () => {
        appendElement(containerElement, iconElement);
        iconElement.classList.remove("hidden");
        return () => {
          if (iconElement.isConnected && containerElement?.contains(iconElement)) {
            containerElement.removeChild(iconElement);
          }
        };
      });
    }
    sideEffect(name, fn) {
      applyEffect(name, fn, this._cleanups);
    }
    cleanup() {
      execCleanups(this._cleanups);
      this._cleanups = [];
    }
  };

  // assets/video-overlay.css
  var video_overlay_default = '/* -- VIDEO PLAYER OVERLAY */\n:host {\n    outline: 10px solid red;\n    position: absolute;\n    top: 0;\n    left: 0;\n    right: 0;\n    bottom: 0;\n    color: white;\n    z-index: 10000;\n}\n.ddg-video-player-overlay {\n    font-family: system, -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";\n    font-size: 13px;\n    font-weight: 400;\n    line-height: 16px;\n    text-align: center;\n\n    position: absolute;\n    top: 0;\n    left: 0;\n    right: 0;\n    bottom: 0;\n    color: white;\n    z-index: 10000;\n}\n\n.ddg-eyeball svg {\n    width: 60px;\n    height: 60px;\n}\n\n.ddg-vpo-bg {\n    position: absolute;\n    top: 0;\n    left: 0;\n    right: 0;\n    bottom: 0;\n    color: white;\n    text-align: center;\n    background: black;\n}\n\n.ddg-vpo-bg:after {\n    content: " ";\n    position: absolute;\n    display: block;\n    width: 100%;\n    height: 100%;\n    top: 0;\n    left: 0;\n    right: 0;\n    bottom: 0;\n    background: rgba(0,0,0,1); /* this gets overriden if the background image can be found */\n    color: white;\n    text-align: center;\n}\n\n.ddg-video-player-overlay[data-thumb-loaded="true"] .ddg-vpo-bg:after {\n    background: rgba(0,0,0,0.75);\n}\n\n.ddg-vpo-content {\n    position: relative;\n    top: 50%;\n    transform: translate(-50%, -50%);\n    left: 50%;\n    max-width: 90%;\n}\n\n.ddg-vpo-eyeball {\n    margin-bottom: 18px;\n}\n\n.ddg-vpo-title {\n    font-size: 22px;\n    font-weight: 400;\n    line-height: 26px;\n    margin-top: 25px;\n}\n\n.ddg-vpo-text {\n    margin-top: 16px;\n    width: 496px;\n    margin-left: auto;\n    margin-right: auto;\n}\n\n.ddg-vpo-text b {\n    font-weight: 600;\n}\n\n.ddg-vpo-buttons {\n    margin-top: 25px;\n}\n.ddg-vpo-buttons > * {\n    display: inline-block;\n    margin: 0;\n    padding: 0;\n}\n\n.ddg-vpo-button {\n    color: white;\n    padding: 9px 16px;\n    font-size: 13px;\n    border-radius: 8px;\n    font-weight: 600;\n    display: inline-block;\n    text-decoration: none;\n}\n\n.ddg-vpo-button + .ddg-vpo-button {\n    margin-left: 10px;\n}\n\n.ddg-vpo-cancel {\n    background: #585b58;\n    border: 0.5px solid rgba(40, 145, 255, 0.05);\n    box-shadow: 0px 0px 0px 0.5px rgba(0, 0, 0, 0.1), 0px 0px 1px rgba(0, 0, 0, 0.05), 0px 1px 1px rgba(0, 0, 0, 0.2), inset 0px 0.5px 0px rgba(255, 255, 255, 0.2), inset 0px 1px 0px rgba(255, 255, 255, 0.05);\n}\n\n.ddg-vpo-open {\n    background: #3969EF;\n    border: 0.5px solid rgba(40, 145, 255, 0.05);\n    box-shadow: 0px 0px 0px 0.5px rgba(0, 0, 0, 0.1), 0px 0px 1px rgba(0, 0, 0, 0.05), 0px 1px 1px rgba(0, 0, 0, 0.2), inset 0px 0.5px 0px rgba(255, 255, 255, 0.2), inset 0px 1px 0px rgba(255, 255, 255, 0.05);\n}\n\n.ddg-vpo-open:hover {\n    background: #1d51e2;\n}\n.ddg-vpo-cancel:hover {\n    cursor: pointer;\n    background: #2f2f2f;\n}\n\n.ddg-vpo-remember {\n}\n.ddg-vpo-remember label {\n    display: flex;\n    align-items: center;\n    justify-content: center;\n    margin-top: 25px;\n    cursor: pointer;\n}\n.ddg-vpo-remember input {\n    margin-right: 6px;\n}\n';

  // src/components/ddg-video-overlay.js
  var DDGVideoOverlay = class extends HTMLElement {
    constructor(environment, params, manager) {
      super();
      if (!(manager instanceof VideoOverlayManager))
        throw new Error("invalid arguments");
      this.environment = environment;
      this.params = params;
      this.manager = manager;
      const shadow = this.attachShadow({ mode: "closed" });
      let style = document.createElement("style");
      style.innerText = video_overlay_default;
      const overlay = this.createOverlay();
      shadow.appendChild(overlay);
      shadow.appendChild(style);
    }
    createOverlay() {
      let overlayElement = document.createElement("div");
      overlayElement.classList.add("ddg-video-player-overlay");
      overlayElement.innerHTML = `
            <div class="ddg-vpo-bg"></div>
            <div class="ddg-vpo-content">
                <div class="ddg-eyeball">${dax_default}</div>
                <div class="ddg-vpo-title">${i18n.t("videoOverlayTitle")}</div>
                <div class="ddg-vpo-text">${i18n.t("videoOverlaySubtitle")}</div>
                <div class="ddg-vpo-buttons">
                    <button class="ddg-vpo-button ddg-vpo-cancel" type="button">${i18n.t("videoButtonOptOut")}</button>
                    <a class="ddg-vpo-button ddg-vpo-open" href="#">${i18n.t("videoButtonOpen")}</a>
                </div>
                <div class="ddg-vpo-remember">
                    <label for="remember">
                        <input id="remember" type="checkbox" name="ddg-remember"> ${i18n.t("rememberLabel")}
                    </label>
                </div>
            </div>
            `;
      const href = this.params.toPrivatePlayerUrl();
      overlayElement.querySelector(".ddg-vpo-open")?.setAttribute("href", href);
      this.appendThumbnail(overlayElement, this.params.id);
      this.setupButtonsInsideOverlay(overlayElement, this.params);
      return overlayElement;
    }
    appendThumbnail(overlayElement, videoId) {
      const imageUrl = this.environment.getLargeThumbnailSrc(videoId);
      appendImageAsBackground(overlayElement, ".ddg-vpo-bg", imageUrl);
    }
    setupButtonsInsideOverlay(containerElement, params) {
      const cancelElement = containerElement.querySelector(".ddg-vpo-cancel");
      const watchInPlayer = containerElement.querySelector(".ddg-vpo-open");
      if (!cancelElement)
        return console.warn("Could not access .ddg-vpo-cancel");
      if (!watchInPlayer)
        return console.warn("Could not access .ddg-vpo-open");
      const optOutHandler = (e) => {
        if (e.isTrusted) {
          const remember = containerElement.querySelector('input[name="ddg-remember"]');
          if (!(remember instanceof HTMLInputElement))
            throw new Error("cannot find our input");
          this.manager.userOptOut(remember.checked, params);
        }
      };
      const watchInPlayerHandler = (e) => {
        if (e.isTrusted) {
          e.preventDefault();
          const remember = containerElement.querySelector('input[name="ddg-remember"]');
          if (!(remember instanceof HTMLInputElement))
            throw new Error("cannot find our input");
          this.manager.userOptIn(remember.checked, params);
        }
      };
      cancelElement.addEventListener("click", optOutHandler);
      watchInPlayer.addEventListener("click", watchInPlayerHandler);
    }
  };
  __publicField(DDGVideoOverlay, "CUSTOM_TAG_NAME", "ddg-video-overlay");
  customElements.define(DDGVideoOverlay.CUSTOM_TAG_NAME, DDGVideoOverlay);

  // src/video-overlay-manager.js
  var VideoOverlayManager = class {
    constructor(userValues, environment, comms) {
      __publicField(this, "lastVideoId", null);
      __publicField(this, "videoPlayerIcon", null);
      __publicField(this, "_cleanups", []);
      this.userValues = userValues;
      this.environment = environment;
      this.comms = comms;
    }
    handleFirstPageLoad() {
      if (!("alwaysAsk" in this.userValues.privatePlayerMode))
        return;
      if (this.userValues.overlayInteracted)
        return;
      const validParams = VideoParams.forWatchPage(this.environment.getHref());
      if (!validParams)
        return;
      this.sideEffect("add css to head", () => {
        const s = document.createElement("style");
        s.innerText = ".html5-video-player { opacity: 0!important }";
        document.head.appendChild(s);
        return () => {
          if (s.isConnected) {
            document.head.removeChild(s);
          }
        };
      });
      this.sideEffect("wait for first video element", () => {
        const int = setInterval(() => {
          this.watchForVideoBeingAdded({ via: "first page load" });
        }, 100);
        return () => {
          clearInterval(int);
        };
      });
    }
    addLargeOverlay(userValues, params) {
      let playerVideo = document.querySelector("#player video"), containerElement = document.querySelector("#player .html5-video-player");
      if (playerVideo && containerElement) {
        this.stopVideoFromPlaying(playerVideo);
        this.appendOverlayToPage(containerElement, params);
      }
    }
    addSmallDaxOverlay(params) {
      let containerElement = document.querySelector("#player .html5-video-player");
      if (!containerElement) {
        console.error("no container element");
        return;
      }
      if (!this.videoPlayerIcon) {
        this.videoPlayerIcon = new VideoPlayerIcon();
      }
      this.videoPlayerIcon.init(containerElement, params);
    }
    watchForVideoBeingAdded(opts = {}) {
      const params = VideoParams.forWatchPage(this.environment.getHref());
      if (!params) {
        return;
      }
      const conditions = [
        opts.ignoreCache,
        !this.lastVideoId,
        this.lastVideoId && this.lastVideoId !== params.id
      ];
      if (conditions.some(Boolean)) {
        const playerElement = document.querySelector("#player");
        if (!playerElement) {
          return null;
        }
        const userValues = this.userValues;
        this.lastVideoId = params.id;
        this.removeAllOverlays();
        if ("enabled" in userValues.privatePlayerMode) {
          this.addSmallDaxOverlay(params);
        }
        if ("alwaysAsk" in userValues.privatePlayerMode) {
          if (!userValues.overlayInteracted) {
            this.addLargeOverlay(userValues, params);
          } else {
            this.addSmallDaxOverlay(params);
          }
        }
        if ("disabled" in userValues.privatePlayerMode) {
        }
      }
    }
    appendOverlayToPage(targetElement, params) {
      this.sideEffect(`appending ${DDGVideoOverlay.CUSTOM_TAG_NAME} to the page`, () => {
        const overlayElement = new DDGVideoOverlay(this.environment, params, this);
        targetElement.appendChild(overlayElement);
        return () => {
          const prevOverlayElement = document.querySelector(DDGVideoOverlay.CUSTOM_TAG_NAME);
          if (prevOverlayElement) {
            prevOverlayElement.parentNode?.removeChild?.(prevOverlayElement);
          } else {
            console.log("exists, but disconnected");
          }
        };
      });
    }
    stopVideoFromPlaying(videoElement) {
      this.sideEffect("pausing the <video> element", () => {
        const int = setInterval(() => {
          if (videoElement instanceof HTMLVideoElement && videoElement.isConnected) {
            videoElement.pause();
          }
        }, 10);
        return () => {
          clearInterval(int);
          if (videoElement?.isConnected) {
            console.log("\u25B6\uFE0F called on original video element");
            videoElement.play();
          } else {
            console.log("\u25B6\uFE0F trying to call 'play()' on newly queried element");
            const video = document.querySelector("#player video");
            if (video instanceof HTMLVideoElement) {
              video.play();
            }
          }
        };
      });
    }
    userOptIn(remember, params) {
      let privatePlayerMode = { alwaysAsk: {} };
      if (remember) {
        privatePlayerMode = { enabled: { name: "shane" } };
      } else {
      }
      const outgoing = {
        overlayInteracted: false,
        privatePlayerMode
      };
      this.userChoice(outgoing).then(() => this.environment.setHref(params.toPrivatePlayerUrl())).catch((e) => console.error("error setting user choice", e));
    }
    userOptOut(remember, params) {
      if (remember) {
        let privatePlayerMode = { alwaysAsk: {} };
        this.userChoice({
          privatePlayerMode,
          overlayInteracted: true
        }).then((values) => this.userValues = values).then(() => this.watchForVideoBeingAdded({ ignoreCache: true, via: "userOptOut" })).catch((e) => console.error("could not set userChoice for opt-out", e));
      } else {
        this.removeAllOverlays();
        this.addSmallDaxOverlay(params);
      }
    }
    userChoice(userValues) {
      return this.comms.setUserValues(userValues).then((userValues2) => {
        console.log("interacted flag set, now cleanup");
        return userValues2;
      }).catch((e) => console.error("could not set interacted after user opt out", e));
    }
    sideEffect(name, fn) {
      applyEffect(name, fn, this._cleanups);
    }
    removeAllOverlays() {
      execCleanups(this._cleanups);
      this._cleanups = [];
      if (this.videoPlayerIcon) {
        this.videoPlayerIcon.cleanup();
      }
      this.videoPlayerIcon = null;
    }
  };

  // youtube-inject.js
  var defaultEnvironment = {
    getHref() {
      return window.location.href;
    },
    getLargeThumbnailSrc(videoId) {
      const url = new URL(`/vi/${videoId}/maxresdefault.jpg`, "https://i.ytimg.com");
      return url.href;
    },
    setHref(href) {
      window.location.href = href;
    },
    enabled() {
      return window.location.hostname === "www.youtube.com";
    }
  };
  var defaultComms = macOSCommunications;
  if (defaultEnvironment.enabled()) {
    initWithEnvironment(defaultEnvironment, defaultComms);
  }
  function initWithEnvironment(environment, comms) {
    defaultComms.readUserValues().then((userValues) => enable(userValues)).catch((e) => console.error(e));
    function enable(userValues) {
      const videoPlayerOverlay = new VideoOverlayManager(userValues, environment, comms);
      videoPlayerOverlay.handleFirstPageLoad();
      defaultComms.onUserValuesNotification((userValues2) => {
        console.log("got new values after zero", userValues2);
        videoPlayerOverlay.userValues = userValues2;
        videoPlayerOverlay.watchForVideoBeingAdded({ via: "user notification", ignoreCache: true });
        if (userValues2.privatePlayerMode.disabled) {
          AllIconOverlays.disable();
          OpenInDuckPlayer.disable();
        } else if (userValues2.privatePlayerMode.enabled) {
          AllIconOverlays.disable();
          OpenInDuckPlayer.enable();
        } else if (userValues2.privatePlayerMode.alwaysAsk) {
          AllIconOverlays.enable();
          OpenInDuckPlayer.disable();
        }
      });
      const CSS = {
        styles: styles_default,
        init: () => {
          let style = document.createElement("style");
          style.textContent = CSS.styles;
          appendElement(document.head, style);
        }
      };
      const VideoThumbnail = {
        isSingleVideoURL: (href) => {
          return href && (href.includes("/watch?v=") && !href.includes("&list=") || href.includes("/watch?v=") && href.includes("&list=") && href.includes("&index=")) && !href.includes("&pp=");
        },
        findAll: () => {
          const linksToVideos = (item) => {
            let href = item.getAttribute("href");
            return VideoThumbnail.isSingleVideoURL(href);
          };
          const linksWithImages = (item) => {
            return item.querySelector("img");
          };
          const linksWithoutSubLinks = (item) => {
            return !item.querySelector('a[href^="/watch?v="]');
          };
          const linksNotInVideoPreview = (item) => {
            let linksInVideoPreview = Array.from(document.querySelectorAll("#preview a"));
            return linksInVideoPreview.indexOf(item) === -1;
          };
          return Array.from(document.querySelectorAll('a[href^="/watch?v="]')).filter(linksToVideos).filter(linksWithoutSubLinks).filter(linksNotInVideoPreview).filter(linksWithImages);
        },
        bindEvents: (video) => {
          if (video) {
            addTrustedEventListener(video, "mouseover", () => {
              IconOverlay.moveHoverOverlayToVideoElement(video);
            });
            addTrustedEventListener(video, "mouseout", IconOverlay.hideHoverOverlay);
          }
        },
        bindEventsToAll: () => {
          VideoThumbnail.findAll().forEach(VideoThumbnail.bindEvents);
        }
      };
      const Preview = {
        previewContainer: false,
        getPreviewVideoLink: () => {
          let linkSelector = 'a[href^="/watch?v="]';
          let previewVideo = document.querySelector("#preview " + linkSelector + " video");
          return previewVideo?.closest(linkSelector);
        },
        appendIfNotAppended: () => {
          let previewVideo = Preview.getPreviewVideoLink();
          if (previewVideo) {
            return IconOverlay.appendToVideo(previewVideo);
          }
          return false;
        },
        update: () => {
          let updateOverlayVideoId = (element) => {
            let overlay = element?.querySelector(".ddg-overlay");
            const href = element?.getAttribute("href");
            if (href) {
              const privateUrl = VideoParams.fromPathname(href)?.toPrivatePlayerUrl();
              if (overlay && privateUrl) {
                overlay.querySelector("a.ddg-play-privately")?.setAttribute("href", privateUrl);
              }
            }
          };
          let videoElement = Preview.getPreviewVideoLink();
          updateOverlayVideoId(videoElement);
        },
        fixLinkClick: () => {
          let previewLink = Preview.getPreviewVideoLink()?.querySelector("a.ddg-play-privately");
          if (!previewLink)
            return;
          addTrustedEventListener(previewLink, "click", () => {
            const href = previewLink?.getAttribute("href");
            if (href) {
              environment.setHref(href);
            }
          });
        },
        init: () => {
          let appended = Preview.appendIfNotAppended();
          if (appended) {
            Preview.fixLinkClick();
          } else {
            Preview.update();
          }
        }
      };
      const AllIconOverlays = {
        enabled: false,
        hasBeenEnabled: false,
        enableOnDOMLoaded: () => {
          onDOMLoaded(() => {
            AllIconOverlays.enable();
          });
        },
        enable: () => {
          if (!AllIconOverlays.hasBeenEnabled) {
            CSS.init();
            onDOMChanged(() => {
              if (AllIconOverlays.enabled) {
                VideoThumbnail.bindEventsToAll();
                Preview.init();
              }
              videoPlayerOverlay.watchForVideoBeingAdded({ via: "mutation observer" });
            });
            window.addEventListener("resize", () => {
              IconOverlay.repositionHoverOverlay();
            });
          }
          IconOverlay.appendHoverOverlay();
          VideoThumbnail.bindEventsToAll();
          AllIconOverlays.enabled = true;
          AllIconOverlays.hasBeenEnabled = true;
        },
        disable: () => {
          AllIconOverlays.enabled = false;
          IconOverlay.removeAll();
        }
      };
      const OpenInDuckPlayer = {
        clickBoundElements: /* @__PURE__ */ new Map(),
        enabled: false,
        bindEventsToAll: () => {
          if (!OpenInDuckPlayer.enabled) {
            return;
          }
          let videoLinksAndPreview = Array.from(document.querySelectorAll('a[href^="/watch?v="], #media-container-link')), isValidVideoLinkOrPreview = (element) => {
            return VideoThumbnail.isSingleVideoURL(element?.getAttribute("href")) || element.getAttribute("id") === "media-container-link";
          }, excludeAlreadyBound = (element) => !OpenInDuckPlayer.clickBoundElements.has(element);
          videoLinksAndPreview.filter(excludeAlreadyBound).forEach((element) => {
            if (isValidVideoLinkOrPreview(element)) {
              let onClickOpenDuckPlayer = (event) => {
                event.preventDefault();
                event.stopPropagation();
                let link = event.target.closest("a");
                if (link) {
                  const href = VideoParams.fromHref(link.href)?.toPrivatePlayerUrl();
                  comms.openInDuckPlayerViaMessage(href);
                }
                return false;
              };
              element.addEventListener("click", onClickOpenDuckPlayer, true);
              OpenInDuckPlayer.clickBoundElements.set(element, onClickOpenDuckPlayer);
            }
          });
        },
        disable: () => {
          OpenInDuckPlayer.clickBoundElements.forEach((functionToRemove, element) => {
            element.removeEventListener("click", functionToRemove, true);
            OpenInDuckPlayer.clickBoundElements.delete(element);
          });
          OpenInDuckPlayer.enabled = false;
        },
        enable: () => {
          OpenInDuckPlayer.enabled = true;
          OpenInDuckPlayer.bindEventsToAll();
          onDOMChanged(() => {
            OpenInDuckPlayer.bindEventsToAll();
          });
        },
        enableOnDOMLoaded: () => {
          OpenInDuckPlayer.enabled = true;
          onDOMLoaded(() => {
            OpenInDuckPlayer.bindEventsToAll();
            onDOMChanged(() => {
              OpenInDuckPlayer.bindEventsToAll();
            });
          });
        }
      };
      if ("alwaysAsk" in userValues.privatePlayerMode) {
        AllIconOverlays.enableOnDOMLoaded();
      } else if ("enabled" in userValues.privatePlayerMode) {
        OpenInDuckPlayer.enableOnDOMLoaded();
      }
    }
  }
})();
