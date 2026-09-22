import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../../core/api.service';

/** Строка ленты лаунчера: и новость, и пункт «Сообщества» устроены одинаково. */
export interface FeedItem {
  date: string;
  title: string;
  body: string;
  url: string;
}

export interface UiLink {
  text: string;
  url: string;
}

export interface UiFeed {
  title?: string;
  moreText?: string;
  moreUrl?: string;
  items?: FeedItem[];
}

export interface UiPlay {
  text?: string;
  updateText?: string;
}

/** Подписи и ссылки окна лаунчера — то, что лежит в ui.json на CDN. */
export interface UiDoc {
  header?: UiLink;
  links?: UiLink[];
  news?: UiFeed;
  community?: UiFeed;
  play?: UiPlay;
}

export interface SaveResult {
  ok: boolean;
  path?: string;
  bytes?: number;
}

@Injectable()
export class CdnApi {
  private readonly api = inject(ApiService);

  news(): Observable<{ items: FeedItem[] }> {
    return this.api.get<{ items: FeedItem[] }>('/cdn/news');
  }

  saveNews(items: FeedItem[]): Observable<SaveResult> {
    return this.api.put<SaveResult>('/cdn/news', { items });
  }

  ui(): Observable<UiDoc> {
    return this.api.get<UiDoc>('/cdn/ui');
  }

  saveUi(doc: UiDoc): Observable<SaveResult> {
    return this.api.put<SaveResult>('/cdn/ui', doc);
  }
}
