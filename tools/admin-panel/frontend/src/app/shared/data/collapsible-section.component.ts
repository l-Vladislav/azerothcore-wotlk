import { Component, input, signal } from '@angular/core';
import { IconComponent } from '../ui/icon.component';

@Component({
  imports: [IconComponent],
  selector: 'app-collapsible-section',
  styleUrl: './collapsible-section.component.scss',
  template: `
    <section>
      <button type="button" class="section-head" (click)="collapsed.update((value) => !value)">
        <span>{{ title() }}</span
        ><app-icon tone="plain" [name]="collapsed() ? 'caret-right' : 'caret'" [size]="13" />
      </button>
      @if (!collapsed()) {
        <div class="body"><ng-content /></div>
      }
    </section>
  `,
})
export class CollapsibleSectionComponent {
  readonly title = input.required<string>();
  readonly collapsed = signal(false);
}
