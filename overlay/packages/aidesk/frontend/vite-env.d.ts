/// <reference types="vite/client" />

declare const __APP_VERSION__: string;

interface ImportMetaEnv {
  /** Origin of the API when it is deployed apart from the static SPA. */
  readonly VITE_API_ORIGIN?: string;
  /** Origin of Authelia, used for the unauthenticated redirect. */
  readonly VITE_AUTH_URL?: string;
}
