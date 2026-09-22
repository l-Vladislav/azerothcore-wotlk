import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'app-weather-state-icon',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { 'aria-hidden': 'true' },
  styles: `
    :host {
      display: block;
      height: 20px;
      width: 20px;
    }
    svg {
      display: block;
      height: 100%;
      width: 100%;
    }
  `,
  template: `
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      @switch (state()) {
        @case (0) {
          <circle cx="12" cy="12" r="4.2" />
          <path
            d="M12 3.4v2.2M12 18.4v2.2M3.4 12h2.2M18.4 12h2.2M6 6l1.6 1.6M16.4 16.4L18 18M18 6l-1.6 1.6M7.6 16.4L6 18"
          />
        }
        @case (1) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path d="M5 18.5h11M7.5 21h9" />
        }
        @case (3) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path d="M12 17.5l-1 3" />
        }
        @case (4) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path d="M9.5 17.5l-1 3M14.5 17.5l-1 3" />
        }
        @case (5) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path d="M7.5 17.5l-1 3M12 17.5l-1 3M16.5 17.5l-1 3" />
        }
        @case (6) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path d="M12 17.4v3.8M10.1 18.4l3.8 1.9M13.9 18.4l-3.8 1.9" />
        }
        @case (7) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path
            d="M9.5 17.4v3.8M7.6 18.4l3.8 1.9M11.4 18.4l-3.8 1.9M14.5 17.4v3.8M12.6 18.4l3.8 1.9M16.4 18.4l-3.8 1.9"
          />
        }
        @case (8) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path
            d="M7.5 17.4v3.8M5.6 18.4l3.8 1.9M9.4 18.4l-3.8 1.9M12 17.4v3.8M10.1 18.4l3.8 1.9M13.9 18.4l-3.8 1.9M16.5 17.4v3.8M14.6 18.4l3.8 1.9M18.4 18.4l-3.8 1.9"
          />
        }
        @case (22) {
          <path d="M4 12h10.5a1.8 1.8 0 1 0-1.8-1.8" />
        }
        @case (41) {
          <path d="M4 9.5h10.5a1.8 1.8 0 1 0-1.8-1.8M4 14.5h10.5a1.8 1.8 0 1 0-1.8-1.8" />
        }
        @case (42) {
          <path
            d="M4 7h10.5a1.8 1.8 0 1 0-1.8-1.8M4 12h10.5a1.8 1.8 0 1 0-1.8-1.8M4 17h10.5a1.8 1.8 0 1 0-1.8-1.8"
          />
        }
        @case (91) {
          <path d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z" />
          <path d="M12.8 17l-2.6 3.2h2.8L11.4 23" />
        }
        @case (90) {
          <path
            d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z"
            fill="currentColor"
            fill-opacity=".55"
          />
          <path d="M9.5 17.5l-1 3M14.5 17.5l-1 3" />
        }
        @case (106) {
          <path
            d="M7.5 15.5h8.7a3.1 3.1 0 0 0 .3-6.2 4.5 4.5 0 0 0-8.7-.6 3 3 0 0 0-.3 6.8z"
            fill="currentColor"
            fill-opacity=".55"
          />
          <path
            d="M9.5 17.4v3.8M7.6 18.4l3.8 1.9M11.4 18.4l-3.8 1.9M14.5 17.4v3.8M12.6 18.4l3.8 1.9M16.4 18.4l-3.8 1.9"
          />
        }
        @default {
          <circle cx="12" cy="12" r="6" />
        }
      }
    </svg>
  `,
})
export class WeatherStateIconComponent {
  readonly state = input.required<number>();
}
