import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);

  get<T>(path: string) {
    return this.http.get<T>(`/api${path}`, { withCredentials: true });
  }

  getText(path: string) {
    return this.http.get(`/api${path}`, { withCredentials: true, responseType: 'text' });
  }

  post<T>(path: string, body?: unknown) {
    return this.http.post<T>(`/api${path}`, body, { withCredentials: true });
  }

  put<T>(path: string, body: unknown) {
    return this.http.put<T>(`/api${path}`, body, { withCredentials: true });
  }

  patch<T>(path: string, body: unknown) {
    return this.http.patch<T>(`/api${path}`, body, { withCredentials: true });
  }

  delete<T>(path: string) {
    return this.http.delete<T>(`/api${path}`, { withCredentials: true });
  }
}
