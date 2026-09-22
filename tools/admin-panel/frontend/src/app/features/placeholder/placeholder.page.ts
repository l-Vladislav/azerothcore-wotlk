import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-placeholder-page',
  styleUrl: './placeholder.page.scss',
  templateUrl: './placeholder.page.html',
})
export class PlaceholderPage {
  private readonly route = inject(ActivatedRoute);
  readonly title = this.route.snapshot.data['title'] as string;
  readonly legacyUrl = this.route.snapshot.data['legacyUrl'] as string;
}
