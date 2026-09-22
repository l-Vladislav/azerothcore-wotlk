import { HttpInterceptorFn, HttpResponse } from '@angular/common/http';
import { Injector, inject } from '@angular/core';
import { tap } from 'rxjs';
import { DeployService } from './deploy.service';

/** Свои же ручки выкатки: их ответ и так несёт состояние. */
const OWN = ['/api/apply', '/api/exports'];

/**
 * После любой удавшейся правки пересчитать «сколько ждёт мира».
 *
 * Здесь, а не в страницах, по той же причине, по какой на сервере отметку
 * ставит прослойка журнала: счёт, который нужно помнить в сорока местах - это
 * счёт с дырами. Новая страница попадает сюда в день, когда её написали.
 */
export const deployInterceptor: HttpInterceptorFn = (request, next) => {
  // Лениво, как и в `sessionInterceptor`: служба сама сидит на HttpClient.
  const injector = inject(Injector);
  const watch =
    request.method !== 'GET' &&
    request.url.startsWith('/api/') &&
    !OWN.some((path) => request.url.startsWith(path));

  if (!watch) return next(request);

  return next(request).pipe(
    tap((event) => {
      if (event instanceof HttpResponse && event.status < 400) {
        injector.get(DeployService).schedule();
      }
    }),
  );
};
