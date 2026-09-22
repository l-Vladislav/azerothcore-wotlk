import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = async (_route, target) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const loginUrl = router.createUrlTree(['/login'], { queryParams: { returnUrl: target.url } });

  try {
    const state = await auth.loadState();
    return state.signed_in || loginUrl;
  } catch {
    return loginUrl;
  }
};
