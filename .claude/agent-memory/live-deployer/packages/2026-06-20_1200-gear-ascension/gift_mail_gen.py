# -*- coding: utf-8 -*-
# Generates gift-mail SQL for acore_characters (gear-ascension kits to real players).
# Safe high id/guid bases to avoid collision with the running server's generators.
import io

DELIVER = 1781938700      # now-ish (epoch)
EXPIRE  = 1789714760      # now + 90 days
SENDER  = 3851            # Admin char guid
STATIONERY = 41
MSGTYPE = 0
COUNT = 20
ENCH = "0 " * 36          # mirror item_instance.enchantments format
# IMPORTANT: charges must mirror the item_template.spellcharges_N columns, slot-for-slot.
# The kits (200000-200020) and the slime (110098) all have spellcharges_1 = -1
# (unlimited-use consumable). A '0' in slot 1 makes the client report "out of charges".
# If you gift an item with no charge-bearing spell, use "0 0 0 0 0 " instead.
CHARGES = "-1 0 0 0 0 "

MAIL_ID = 2000000001
ITEM_GUID = 2100000001

players = [(564, "Zmrtgrbm"), (565, "Magicarp"), (13853, "Мистермускул")]

# (subject, body, [tier1, tier2, tier3])
vendors = [
 ("Из кузни Оргриммара",
  "Lok'tar, воин! В Оргриммаре куют сталь, что не знает страха. Прими наборы для ковки - по двадцать на каждую ступень. Закали ими латы, кольчугу и щит, как закаляют клинки в Долине Чести. Выйдут - ищи меня у трактирщика. За Орду! - Громдар Чёрный Молот",
  [200000,200001,200002]),
 ("Шкура зверя",
  "Земля-Мать благоволит тебе. Хорошая шкура - дар зверя, и чтить его надо умело. Прими наборы для выделки - по двадцать на каждую ступень. Укрепи ими кожу и чешую, хоть бы и шкуру дьявозавра. Понадобится - я при трактирщике. Иди с духами. - Хемнак Грубокож",
  [200003,200004,200005]),
 ("Нити Подгорода",
  "Приветствую, дитя Тьмы. Нити помнят холод Подгорода. Высылаю наборы для шитья - по двадцать на каждую ступень. Переплети ими одеяния, от льняного до рунического, и они впитают больше силы. За новыми - к трактирщику. Тьма хранит. - Морвена Хладонить",
  [200006,200007,200008]),
 ("Грань самоцвета",
  "Selama ashal'anore. Камень поёт лишь в умелых руках. Дарю наборы для огранки - по двадцать на каждую ступень. Огранируй кольца, амулеты и подвески, от цитрина до арканового кристалла. Нужно ещё - моя витрина у трактирщика. Сияй ярче Солнечного Колодца. - Аэлинор Самоцвет",
  [200009,200010,200011]),
 ("С точильного камня",
  "Точи клинок, или клинок затупит тебя. Шлю точильные наборы - по двадцать на каждую ступень. Пройди ими по топору, мечу или булаве, и кромка станет злее тролльего клыка. Сточатся - я у трактирщика. Кровь и честь! - Каргал Острокром",
  [200012,200013,200014]),
 ("Шёпот вуду",
  "Слушай духов, мон. Дерево - ничто, руна - всё. Прими наборы чар - по двадцать на каждую ступень. Влей ими в посох да жезл тайную мощь, что течёт от Зул'Гуруба до Награнда. Иссякнут - ищи меня в тенях у трактирщика. Духи с тобой. - Зен'тари Рунопряд",
  [200015,200016,200017]),
 ("С доставкой, бабах!",
  "Время - деньги, дружище! Меткость - тоже. Кидаю наборы для оснастки - по двадцать на каждую ступень. Подкрути ими луки, ружья и арбалеты, хоть мифриловым воротом, хоть торием. Запас вышел - стучи через трактирщика. Бабах!.. в смысле, удачи. - Бликс Меднокрут",
  [200018,200019,200020]),
]

def esc(s):
    return s.replace("'", "''")

mail_id = MAIL_ID
item_guid = ITEM_GUID
out = []
out.append("-- Gear Ascension gift mail (auto-generated). Idempotent.")
out.append("DELETE FROM mail_items WHERE mail_id BETWEEN 2000000001 AND 2000000099;")
out.append("DELETE FROM item_instance WHERE guid BETWEEN 2100000001 AND 2100000099;")
out.append("DELETE FROM mail WHERE id BETWEEN 2000000001 AND 2000000099;")

for (pg, pname) in players:
    for (subj, body, entries) in vendors:
        out.append(
            "INSERT INTO mail (id,messageType,stationery,mailTemplateId,sender,receiver,subject,body,has_items,expire_time,deliver_time,money,cod,checked) "
            "VALUES (%d,%d,%d,0,%d,%d,'%s','%s',1,%d,%d,0,0,0);"
            % (mail_id, MSGTYPE, STATIONERY, SENDER, pg, esc(subj), esc(body), EXPIRE, DELIVER))
        for e in entries:
            out.append(
                "INSERT INTO item_instance (guid,itemEntry,owner_guid,creatorGuid,giftCreatorGuid,count,duration,charges,flags,enchantments,randomPropertyId,durability,playedTime,text) "
                "VALUES (%d,%d,%d,0,0,%d,0,'%s',0,'%s',0,0,0,'');"
                % (item_guid, e, pg, COUNT, CHARGES, ENCH))
            out.append("INSERT INTO mail_items (mail_id,item_guid,receiver) VALUES (%d,%d,%d);"
                       % (mail_id, item_guid, pg))
            item_guid += 1
        mail_id += 1

with io.open("gift_mail.sql", "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
print("mails=%d items=%d -> gift_mail.sql" % (mail_id-MAIL_ID, item_guid-ITEM_GUID))
