import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { Injector, inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';

/** Ручки, 401 от которых - обычный ответ формы, а не потерянная сессия. */
const OWN_SIGN_IN = ['/api/auth/login', '/api/auth/state', '/api/invites'];

/**
 * Протухшая сессия возвращает на вход, а не рассыпается по страницам.
 *
 * Страж проверяет вход только при переходе, поэтому открытая вкладка, у
 * которой кончилась сессия, до сих пор показывала на каждой странице своё
 * «не удалось загрузить» - и человек читал это как поломку панели.
 */
export const sessionInterceptor: HttpInterceptorFn = (request, next) => {
  // Службы берём ЛЕНИВО, через инжектор: AuthService сам сидит на HttpClient,
  // и запрошенный прямо здесь он замыкает кольцо - запрос падает ещё до сети,
  // а страница показывает «сервер не принял», хотя сервера никто не спрашивал.
  const injector = inject(Injector);

  return next(request).pipe(
    catchError((error: unknown) => {
      const lost =
        error instanceof HttpErrorResponse &&
        error.status === 401 &&
        !OWN_SIGN_IN.some((path) => request.url.startsWith(path));
      if (lost) {
        const router = injector.get(Router);
        if (!router.url.startsWith('/login')) {
          injector.get(AuthService).forget();
          void router.navigate(['/login'], { queryParams: { returnUrl: router.url } });
        }
      }
      return throwError(() => error);
    }),
  );
};
