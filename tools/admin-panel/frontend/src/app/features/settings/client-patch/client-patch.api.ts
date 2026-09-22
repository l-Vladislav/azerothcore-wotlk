import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../../core/api.service';

export interface PatchHealth {
  build_py?: boolean;
  workdir?: boolean;
  base_ready?: boolean;
  cdn?: boolean;
  stormlib?: boolean;
}

export interface PatchStatus {
  configured: boolean;
  reachable: boolean;
  running?: boolean;
  command?: string | null;
  started?: string | null;
  finished?: string | null;
  code?: number | null;
  log_tail?: string;
  error?: string;
  health?: PatchHealth;
}

export interface BuildOptions {
  dry_run?: boolean;
  no_publish?: boolean;
  no_manifest?: boolean;
}

@Injectable()
export class ClientPatchApi {
  private readonly api = inject(ApiService);

  status(): Observable<PatchStatus> {
    return this.api.get<PatchStatus>('/patch/status');
  }

  log(): Observable<string> {
    return this.api.getText('/patch/log');
  }

  build(options: BuildOptions): Observable<PatchStatus> {
    return this.api.post<PatchStatus>('/patch/build', options);
  }

  bootstrap(): Observable<PatchStatus> {
    return this.api.post<PatchStatus>('/patch/bootstrap', { force: true });
  }
}
