import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideHttpClient, withFetch, withInterceptors } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { routes } from './app.routes';
import { provideFeatureNavigation } from './core/navigation/feature-navigation';
import { featureNavigation } from './features/feature-navigation.config';
import { authInterceptor } from './core/auth.interceptor';
import { sessionInterceptor } from './core/session.interceptor';
import { deployInterceptor } from './core/deploy.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(withFetch(), withInterceptors([authInterceptor, sessionInterceptor, deployInterceptor])),
    provideFeatureNavigation(...featureNavigation),
  ],
};
