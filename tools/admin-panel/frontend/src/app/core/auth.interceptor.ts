import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (request, next) => {
  const token = localStorage.getItem('adminToken');
  const authenticated = token
    ? request.clone({ setHeaders: { 'X-Admin-Token': token }, withCredentials: true })
    : request.clone({ withCredentials: true });
  return next(authenticated);
};
