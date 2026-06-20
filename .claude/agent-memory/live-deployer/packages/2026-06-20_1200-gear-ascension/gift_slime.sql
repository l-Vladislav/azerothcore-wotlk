-- Gift: Slime familiar (item 110098) to SET/Мистермускул (guid 13853), from Innkeeper (190002). Idempotent.
DELETE FROM mail_items WHERE mail_id = 2000000100;
DELETE FROM item_instance WHERE guid = 2100000100;
DELETE FROM mail WHERE id = 2000000100;
INSERT INTO mail (id,messageType,stationery,mailTemplateId,sender,receiver,subject,body,has_items,expire_time,deliver_time,money,cod,checked)
VALUES (2000000100,3,41,0,190002,13853,'Спутник в дорогу','Здравствуй, Мистермускул! Забрёл к нам в трактир один склизкий, но славный малый - Слайм. Пристал, не отвадить. Дарю тебе клетку с ним: выпустишь - будет скакать следом, и, сказывают, рядом с ним и наука легче даётся, и слава растёт быстрее. Не держи его у огня - расплавится. Доброй дороги! - Трактирщик',1,1789714760,1781938700,0,0,0);
INSERT INTO item_instance (guid,itemEntry,owner_guid,creatorGuid,giftCreatorGuid,count,duration,charges,flags,enchantments,randomPropertyId,durability,playedTime,text)
VALUES (2100000100,110098,13853,0,0,1,0,'-1 0 0 0 0 ',0,'0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ',0,0,0,'');
INSERT INTO mail_items (mail_id,item_guid,receiver) VALUES (2000000100,2100000100,13853);
