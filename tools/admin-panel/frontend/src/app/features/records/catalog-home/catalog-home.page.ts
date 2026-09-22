import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { IconComponent } from '../../../shared/ui/icon.component';

@Component({
  imports: [RouterLink, IconComponent],
  selector: 'app-catalog-home-page',
  styleUrl: './catalog-home.page.scss',
  templateUrl: './catalog-home.page.html',
})
export class CatalogHomePage {}
