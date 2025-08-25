const CHARSET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const BASE: u64 = 62;

pub fn encode_base62(mut num: u64) -> String {
    if num == 0 {
        return (CHARSET[0] as char).to_string();
    }

    let mut chars = [0u8; 11];
    let mut pos = chars.len();

    while num > 0 {
        pos -= 1;
        chars[pos] = CHARSET[(num % BASE) as usize];
        num /= BASE;
    }

    String::from_utf8(chars[pos..].to_vec()).unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encode_base62_zero() {
        assert_eq!(encode_base62(0), "a");
    }

    #[test]
    fn test_encode_base62_small() {
        assert_eq!(encode_base62(1), "b");
        assert_eq!(encode_base62(61), "9");
    }

    #[test]
    fn test_encode_base62_large() {
        assert_eq!(encode_base62(62), "ba");
        assert_eq!(encode_base62(3844), "baa");
    }
}