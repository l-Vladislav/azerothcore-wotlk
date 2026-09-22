import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../../core/api.service';

export interface WorldItemMeta {
  available: boolean;
  icon_base_url: string;
}

export interface WorldItemPlacement {
  id: number;
  item_entry: number;
  item_name: string;
  item_quality: number;
  item_icon: string;
  item_missing: boolean;
  item_block: string | null;
  item_count: number;
  go_entry: number;
  go_guid: number | null;
  map: number;
  zone: number;
  pos: [number, number, number];
  one_per_char: boolean;
  respawn_secs: number;
  enabled: boolean;
  comment: string;
  created_by: string;
  looted_by: number | null;
}

@Injectable()
export class WorldItemsApi {
  private readonly api = inject(ApiService);

  meta() {
    return this.api.get<WorldItemMeta>('/worlditems/meta');
  }

  list(onlyEnabled: boolean) {
    return this.api.get<{ items: WorldItemPlacement[] }>(`/worlditems?only_enabled=${onlyEnabled}`);
  }

  update(
    id: number,
    fields: Partial<
      Pick<
        WorldItemPlacement,
        'item_entry' | 'item_count' | 'one_per_char' | 'respawn_secs' | 'enabled' | 'comment'
      >
    >,
  ) {
    return this.api.patch<WorldItemPlacement>(`/worlditems/${id}`, { fields });
  }

  resetLoot(id: number) {
    return this.api.post<{ ok: boolean; forgotten: number }>(`/worlditems/${id}/reset-loot`);
  }

  delete(id: number) {
    return this.api.delete<{ ok: boolean }>(`/worlditems/${id}`);
  }
}
