-- Fix: gift-mailed kits (200000-200020) and gift slime (110098) have spellcharges_1 = -1,
-- so item_instance.charges must be '-1 0 0 0 0 ' (slot 1 = -1 = unlimited consumable use),
-- not '0 0 0 0 0 ' (slot 1 = 0 = "out of charges"). gift_mail_gen.py hardcoded the wrong value.
-- 63 gift kits + 1 gift slime. acore_characters. Idempotent.
UPDATE item_instance SET charges='-1 0 0 0 0 ' WHERE guid BETWEEN 2100000001 AND 2100000063;
UPDATE item_instance SET charges='-1 0 0 0 0 ' WHERE guid = 2100000100;
