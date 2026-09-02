import { config } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import i18nMessages from 'dashboard/i18n';
import FloatingVue from 'floating-vue';

const createStorageMock = () => {
  let store = {};
  const target = {
    getItem: key => (Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null),
    setItem: (key, value) => {
      store[key] = String(value);
    },
    removeItem: key => {
      delete store[key];
    },
    clear: () => {
      store = {};
    },
    get length() {
      return Object.keys(store).length;
    },
    key: index => Object.keys(store)[index] || null,
  };

  return new Proxy(target, {
    get(t, prop) {
      if (prop in t || typeof prop === 'symbol') {
        return t[prop];
      }
      return Object.prototype.hasOwnProperty.call(store, prop) ? store[prop] : undefined;
    },
    set(t, prop, value) {
      if (prop in t) {
        t[prop] = value;
      } else {
        store[prop] = String(value);
      }
      return true;
    },
    deleteProperty(t, prop) {
      if (prop in t) {
        delete t[prop];
      } else {
        delete store[prop];
      }
      return true;
    },
    has(t, prop) {
      return prop in t || Object.prototype.hasOwnProperty.call(store, prop);
    },
    ownKeys() {
      return [...Reflect.ownKeys(target), ...Object.keys(store)];
    },
    getOwnPropertyDescriptor(t, prop) {
      if (prop in t) {
        return Reflect.getOwnPropertyDescriptor(t, prop);
      }
      if (Object.prototype.hasOwnProperty.call(store, prop)) {
        return {
          value: store[prop],
          writable: true,
          enumerable: true,
          configurable: true,
        };
      }
      return undefined;
    },
  });
};

const localStorageMock = createStorageMock();
const sessionStorageMock = createStorageMock();

Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageMock,
  configurable: true,
  writable: true,
});

if (typeof window !== 'undefined') {
  Object.defineProperty(window, 'localStorage', {
    value: localStorageMock,
    configurable: true,
    writable: true,
  });
}

Object.defineProperty(globalThis, 'sessionStorage', {
  value: sessionStorageMock,
  configurable: true,
  writable: true,
});

if (typeof window !== 'undefined') {
  Object.defineProperty(window, 'sessionStorage', {
    value: sessionStorageMock,
    configurable: true,
    writable: true,
  });
}

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: i18nMessages,
});

config.global.plugins = [i18n, FloatingVue];
config.global.stubs = {
  WootModal: { template: '<div><slot/></div>' },
  WootModalHeader: { template: '<div><slot/></div>' },
  NextButton: { template: '<button><slot/></button>' },
};

