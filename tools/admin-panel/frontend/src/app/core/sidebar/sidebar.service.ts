import { Injectable, TemplateRef, signal } from '@angular/core';

export interface SidebarContent {
  label: string;
  template: TemplateRef<unknown>;
}

@Injectable({ providedIn: 'root' })
export class SidebarService {
  readonly collapsed = signal(localStorage.getItem('adminSidebarCollapsed') !== 'false');
  readonly content = signal<SidebarContent | null>(null);

  toggle(): void {
    this.collapsed.update((collapsed) => !collapsed);
    localStorage.setItem('adminSidebarCollapsed', String(this.collapsed()));
  }

  register(content: SidebarContent): () => void {
    this.content.set(content);
    return () => {
      if (this.content()?.template === content.template) this.content.set(null);
    };
  }
}
