import { loadScript } from 'dashboard/helper/DOMHelpers';

const FACEBOOK_SDK_URL = 'https://connect.facebook.net/en_US/sdk.js';
const FACEBOOK_SDK_TIMEOUT = 15000;

export const loadFacebookSdk = async () => {
  if (window.FB) {
    return window.FB;
  }

  return loadScript(FACEBOOK_SDK_URL, {
    id: 'facebook-jssdk',
    async: true,
    defer: true,
    crossOrigin: 'anonymous',
  });
};

export const initializeFacebook = (appId, apiVersion) => {
  const version = apiVersion || 'v22.0';
  return new Promise(resolve => {
    const init = () => {
      window.FB.init({
        appId,
        autoLogAppEvents: true,
        xfbml: true,
        version,
      });
      resolve();
    };

    if (window.FB) {
      init();
    } else {
      window.fbAsyncInit = init;
    }
  });
};

export const isValidBusinessData = businessData => {
  return Boolean(businessData?.waba_id);
};

const ALLOWED_FACEBOOK_ORIGINS = new Set([
  'https://www.facebook.com',
  'https://web.facebook.com',
  'https://m.facebook.com',
  'https://facebook.com',
  'https://business.facebook.com',
]);

export const createMessageHandler = onEmbeddedSignupData => {
  return event => {
    if (!ALLOWED_FACEBOOK_ORIGINS.has(event.origin)) return;

    try {
      let data;
      if (typeof event.data === 'string') {
        data = JSON.parse(event.data);
      } else if (typeof event.data === 'object' && event.data !== null) {
        data = event.data;
      } else {
        return;
      }

      if (data.type === 'WA_EMBEDDED_SIGNUP') {
        onEmbeddedSignupData(data);
      }
    } catch {
      // Ignore non-JSON or irrelevant messages
    }
  };
};

export const initWhatsAppEmbeddedSignup = configId => {
  return new Promise((resolve, reject) => {
    if (!window.FB) {
      reject(new Error('Facebook SDK is not ready'));
      return;
    }

    if (!configId) {
      reject(new Error('WhatsApp Configuration ID is required'));
      return;
    }

    if (window.location.protocol !== 'https:') {
      reject(
        new Error(
          'A Meta exige HTTPS para abrir o login do WhatsApp Business. Use um domínio HTTPS configurado no app da Meta.'
        )
      );
      return;
    }

    window.FB.login(
      response => {
        if (response.authResponse && response.authResponse.code) {
          resolve(response.authResponse.code);
        } else if (response.error?.message) {
          reject(new Error(response.error.message));
        } else if (response.error) {
          reject(new Error(response.error));
        } else {
          reject(new Error('Login cancelled'));
        }
      },
      {
        config_id: configId,
        auth_type: 'rerequest',
        response_type: 'code',
        override_default_response_type: true,
        extras: {
          sessionInfoVersion: '3',
        },
      }
    );
  });
};

export const setupFacebookSdk = async (appId, apiVersion) => {
  if (!appId) {
    throw new Error('WhatsApp App ID is required');
  }

  const version = apiVersion || 'v22.0';
  await Promise.race([
    loadFacebookSdk(),
    new Promise((resolve, reject) => {
      setTimeout(
        () => reject(new Error('Facebook SDK load timed out')),
        FACEBOOK_SDK_TIMEOUT
      );
    }),
  ]);
  await initializeFacebook(appId, version);
};
