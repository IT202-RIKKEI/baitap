
DROP DATABASE IF EXISTS social_network;
CREATE DATABASE social_network CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE social_network;

-- PHAN 1: TAO CAC BANG (TABLES)

-- Bang users: luu thong tin nguoi dung
CREATE TABLE users (
    user_id     INT AUTO_INCREMENT PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL UNIQUE,
    email       VARCHAR(100) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Bang posts: luu bai viet
CREATE TABLE posts (
    post_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT          NOT NULL,
    content       TEXT         NOT NULL,
    like_count    INT          DEFAULT 0,
    comment_count INT          DEFAULT 0,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Bang comments: luu binh luan
CREATE TABLE comments (
    comment_id  INT AUTO_INCREMENT PRIMARY KEY,
    post_id     INT          NOT NULL,
    user_id     INT          NOT NULL,
    content     TEXT         NOT NULL,
    created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_post FOREIGN KEY (post_id) REFERENCES posts(post_id),
    CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Bang likes: luu luot thich (moi nguoi chi like 1 bai 1 lan)
CREATE TABLE likes (
    like_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    post_id    INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_likes_post FOREIGN KEY (post_id) REFERENCES posts(post_id),
    CONSTRAINT uq_likes UNIQUE (user_id, post_id)   -- moi nguoi chi like 1 lan
);

-- Bang friends: luu moi quan he ket ban
CREATE TABLE friends (
    friend_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    friend_id_2 INT NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_friends_user   FOREIGN KEY (user_id)     REFERENCES users(user_id),
    CONSTRAINT fk_friends_friend FOREIGN KEY (friend_id_2) REFERENCES users(user_id)
);

-- Bang post_logs: luu vet bai viet da xoa (yeu cau mo rong)
CREATE TABLE post_logs (
    log_id       INT AUTO_INCREMENT PRIMARY KEY,
    post_id      INT  NOT NULL,
    post_content TEXT NOT NULL,
    deleted_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- PHAN 2: INDEX
-- Full-Text Search tren cot content cua bang posts

ALTER TABLE posts ADD FULLTEXT INDEX ft_posts_content (content);

-- PHAN 3: VIEW - Chuc nang 1
-- view_user_info: chi lay thong tin an toan, khong co password

CREATE VIEW view_user_info AS
SELECT
    user_id,
    username,
    email,
    created_at
FROM users;

-- PHAN 4: STORED PROCEDURES

DELIMITER $$

-- Chuc nang 2: Dang ky tai khoan
-- sp_add_user: kiem tra trung lap roi moi INSERT
CREATE PROCEDURE sp_add_user (
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email    VARCHAR(100)
)
BEGIN
    -- Kiem tra email hoac username da ton tai chua
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        SELECT 'Loi: Email nay da duoc su dung!' AS message;

    ELSEIF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        SELECT 'Loi: Username nay da duoc su dung!' AS message;

    ELSE
        INSERT INTO users (username, password, email)
        VALUES (p_username, p_password, p_email);

        SELECT 'Dang ky tai khoan thanh cong!' AS message;
    END IF;
END$$

-- Chuc nang 4: Thong ke hoat dong cua tung user
-- sp_user_activity_report: dung LEFT JOIN de hien thi ca user moi
CREATE PROCEDURE sp_user_activity_report()
BEGIN
    SELECT
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id)   AS tong_bai_viet,
        COUNT(DISTINCT l.like_id)   AS tong_luot_like,
        COUNT(DISTINCT c.comment_id) AS tong_binh_luan
    FROM users u
    LEFT JOIN posts    p ON p.user_id = u.user_id
    LEFT JOIN likes    l ON l.user_id = u.user_id
    LEFT JOIN comments c ON c.user_id = u.user_id
    GROUP BY u.user_id, u.username
    ORDER BY u.user_id;
END$$

-- Chuc nang 5: Xoa tai khoan toan ven (dung Transaction)
-- sp_delete_user: xoa tu bang con len bang cha, All-or-Nothing
CREATE PROCEDURE sp_delete_user (
    IN p_user_id INT
)
BEGIN
    -- Khai bao bien bat loi
    DECLARE v_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

    -- Kiem tra user co ton tai khong
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SELECT 'Loi: Khong tim thay user!' AS message;
    ELSE
        START TRANSACTION;

        -- Buoc 1: Xoa likes cua user nay
        DELETE FROM likes WHERE user_id = p_user_id;

        -- Buoc 2: Xoa likes tren cac bai viet cua user nay
        DELETE FROM likes WHERE post_id IN (
            SELECT post_id FROM posts WHERE user_id = p_user_id
        );

        -- Buoc 3: Xoa comments cua user nay
        DELETE FROM comments WHERE user_id = p_user_id;

        -- Buoc 4: Xoa comments tren bai viet cua user nay
        DELETE FROM comments WHERE post_id IN (
            SELECT post_id FROM posts WHERE user_id = p_user_id
        );

        -- Buoc 5: Xoa ket ban (ca 2 chieu)
        DELETE FROM friends WHERE user_id = p_user_id OR friend_id_2 = p_user_id;

        -- Buoc 6: Xoa bai viet cua user nay
        DELETE FROM posts WHERE user_id = p_user_id;

        -- Buoc 7: Xoa chinh user
        DELETE FROM users WHERE user_id = p_user_id;

        -- Kiem tra neu co loi thi ROLLBACK, nguoc lai COMMIT
        IF v_error = 1 THEN
            ROLLBACK;
            SELECT 'Loi: Xoa that bai! Da rollback toan bo giao dich.' AS message;
        ELSE
            COMMIT;
            SELECT 'Xoa tai khoan thanh cong!' AS message;
        END IF;
    END IF;
END$$

DELIMITER ;

-- PHAN 5: TRIGGERS

DELIMITER $$

-- Chuc nang 3a: Tu dong +1 like_count khi co like moi

CREATE TRIGGER tg_after_like_insert
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
    UPDATE posts
    SET like_count = like_count + 1
    WHERE post_id = NEW.post_id;
END$$

-- Chuc nang 3b: Tu dong -1 like_count khi xoa like
-- Chan khong cho xuong duoi 0

CREATE TRIGGER tg_after_like_delete
AFTER DELETE ON likes
FOR EACH ROW
BEGIN
    UPDATE posts
    SET like_count = CASE
                        WHEN like_count > 0 THEN like_count - 1
                        ELSE 0
                     END
    WHERE post_id = OLD.post_id;
END$$

-- Chuc nang 3c: Tu dong +1 comment_count khi co comment moi

CREATE TRIGGER tg_after_comment_insert
AFTER INSERT ON comments
FOR EACH ROW
BEGIN
    UPDATE posts
    SET comment_count = comment_count + 1
    WHERE post_id = NEW.post_id;
END$$

-- Chuc nang 3d: Tu dong -1 comment_count khi xoa comment
-- Chan khong cho xuong duoi 0

CREATE TRIGGER tg_after_comment_delete
AFTER DELETE ON comments
FOR EACH ROW
BEGIN
    UPDATE posts
    SET comment_count = CASE
                            WHEN comment_count > 0 THEN comment_count - 1
                            ELSE 0
                        END
    WHERE post_id = OLD.post_id;
END$$

-- Chuc nang 6: Kiem soat ket ban truoc khi INSERT
-- tg_before_friend_insert: chan 3 truong hop vi pham

CREATE TRIGGER tg_before_friend_insert
BEFORE INSERT ON friends
FOR EACH ROW
BEGIN
    -- Loi 1: Tu ket ban voi chinh minh
    IF NEW.user_id = NEW.friend_id_2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Khong the ket ban voi chinh minh!';

    -- Loi 2: Cap nay da ton tai (A->B)
    ELSEIF EXISTS (
        SELECT 1 FROM friends
        WHERE user_id = NEW.user_id AND friend_id_2 = NEW.friend_id_2
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Cap ket ban nay da ton tai!';

    -- Loi 3: Loi moi dao chieu da ton tai (B->A)
    ELSEIF EXISTS (
        SELECT 1 FROM friends
        WHERE user_id = NEW.friend_id_2 AND friend_id_2 = NEW.user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Loi moi dao chieu da ton tai (nguoi kia da gui truoc)!';
    END IF;
END$$

-- ----------------------------------------------------------
-- Chuc nang Mo rong: Luu vet bai viet khi bi xoa
-- tg_after_post_delete: copy noi dung sang bang post_logs
-- ----------------------------------------------------------
CREATE TRIGGER tg_after_post_delete
AFTER DELETE ON posts
FOR EACH ROW
BEGIN
    INSERT INTO post_logs (post_id, post_content, deleted_at)
    VALUES (OLD.post_id, OLD.content, NOW());
END$$

DELIMITER ;

-- PHAN 6: DU LIEU MAU (MOCK DATA) de test
-- Them 3 users mau (password da duoc hash gia su)

INSERT INTO users (username, password, email) VALUES
('nguyen_van_a', 'hashed_pass_1', 'vana@email.com'),
('tran_thi_b',   'hashed_pass_2', 'thib@email.com'),
('le_van_c',     'hashed_pass_3', 'vanc@email.com');

-- Them 3 bai viet mau

INSERT INTO posts (user_id, content) VALUES
(1, 'Hom nay hoc MySQL that thu vi, hieu them ve Trigger roi!'),
(2, 'Stored Procedure giup code sach hon nhieu, tuyet that!'),
(3, 'Transaction la quan trong nhat khi lam viec voi du lieu nha moi nguoi.');

-- Them ket ban (user 1 ket ban voi user 2, user 2 ket ban voi user 3)

INSERT INTO friends (user_id, friend_id_2) VALUES (1, 2);
INSERT INTO friends (user_id, friend_id_2) VALUES (2, 3);

-- Them likes (kich hoat trigger tg_after_like_insert)
INSERT INTO likes (user_id, post_id) VALUES (2, 1);  -- B like bai cua A
INSERT INTO likes (user_id, post_id) VALUES (3, 1);  -- C like bai cua A
INSERT INTO likes (user_id, post_id) VALUES (1, 2);  -- A like bai cua B

-- Them comments (kich hoat trigger tg_after_comment_insert)
INSERT INTO comments (post_id, user_id, content) VALUES
(1, 2, 'Dong y! Trigger that la tien loi ban oi.'),
(1, 3, 'Minh cung dang hoc phan nay, kho that.'),
(2, 1, 'Cam on ban da chia se, rat bo ich!');

-- PHAN 7: TEST THU CAC CHUC NANG


-- Test Chuc nang 1: Xem view ho so nguoi dung
SELECT '=== TEST VIEW_USER_INFO ===' AS test_name;
SELECT * FROM view_user_info;

-- Test Chuc nang 2: Dang ky tai khoan
SELECT '=== TEST SP_ADD_USER ===' AS test_name;
CALL sp_add_user('pham_van_d', 'pass123', 'vand@email.com');         -- Thanh cong
CALL sp_add_user('nguyen_van_a', 'pass456', 'moi@email.com');        -- Loi username trung
CALL sp_add_user('user_moi', 'pass789', 'vana@email.com');            -- Loi email trung

-- Test Chuc nang 3: Kiem tra trigger dem like/comment
SELECT '=== TEST TRIGGER DEM LUOT LIKE VA COMMENT ===' AS test_name;
SELECT post_id, content, like_count, comment_count FROM posts;

-- Test xoa like va kiem tra khong xuong duoi 0
SELECT '=== TEST XOA LIKE ===' AS test_name;
DELETE FROM likes WHERE user_id = 2 AND post_id = 1;
SELECT post_id, like_count FROM posts WHERE post_id = 1;

-- Test Chuc nang 4: Bao cao hoat dong
SELECT '=== TEST SP_USER_ACTIVITY_REPORT ===' AS test_name;
CALL sp_user_activity_report();

-- Test Chuc nang 6: Kiem soat ket ban
SELECT '=== TEST TG_BEFORE_FRIEND_INSERT ===' AS test_name;

-- Test tu ket ban voi chinh minh (phai bao loi)
-- INSERT INTO friends (user_id, friend_id_2) VALUES (1, 1);

-- Test trung lap (phai bao loi)
-- INSERT INTO friends (user_id, friend_id_2) VALUES (1, 2);

-- Test dao chieu (phai bao loi)
-- INSERT INTO friends (user_id, friend_id_2) VALUES (2, 1);

-- Test Chuc nang Mo rong: Trigger luu vet khi xoa bai viet
SELECT '=== TEST TG_AFTER_POST_DELETE ===' AS test_name;
-- Them 1 bai viet tam de xoa thu
INSERT INTO posts (user_id, content) VALUES (1, 'Bai viet nay se bi xoa de test audit log');
DELETE FROM posts WHERE content LIKE '%audit log%';
SELECT * FROM post_logs;

-- Test Chuc nang 5: Xoa tai khoan (test cuoi vi xoa du lieu)
SELECT '=== TEST SP_DELETE_USER ===' AS test_name;
CALL sp_delete_user(99);   -- Xoa user khong ton tai
-- CALL sp_delete_user(1); -- Bo comment de test xoa user that (se xoa het du lieu lien quan)