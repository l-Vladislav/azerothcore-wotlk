import { Observable } from 'rxjs';

export interface CatalogPage<TEntity> {
  items: TEntity[];
  offset: number;
  total: number;
}

export interface ReadonlyCatalog<TEntity, TId, TQuery, TMeta> {
  meta(): Observable<TMeta>;
  search(query: TQuery): Observable<CatalogPage<TEntity>>;
  detail(id: TId): Observable<TEntity>;
}
