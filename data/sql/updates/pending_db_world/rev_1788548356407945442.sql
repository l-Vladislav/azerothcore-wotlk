-- PTR only: fast item-catalogue lookup in the admin panel.
-- The panel itself refuses non-*_ptr schemas; do not apply this to production.
ALTER TABLE `item_template`
    ADD FULLTEXT INDEX `idx_admin_panel_item_name_ft` (`name`);

ALTER TABLE `item_template_locale`
    ADD FULLTEXT INDEX `idx_admin_panel_item_locale_name_ft` (`Name`);
