#!/usr/bin/env python3
import argparse
import sys
try:
    from Crypto.Cipher import AES
except ImportError as exp:
    from Cryptodome.Cipher import AES
from base64 import b64encode, b64decode


class Crypt:

    def __init__(self, salt='T0InPutP@ssW0rD!'):
        self.salt = salt.encode('utf8')
        self.enc_dec_method = 'utf-8'

    def encrypt(self, str_to_enc, str_key):
        try:
            aes_obj = AES.new(str_key.encode('utf-8'), AES.MODE_CFB, self.salt)
            hx_enc = aes_obj.encrypt(str_to_enc.encode('utf8'))
            mret = b64encode(hx_enc).decode(self.enc_dec_method)
            return mret
        except ValueError as value_error:
            if value_error.args[0] == 'IV must be 16 bytes long':
                raise ValueError(
                    'Encryption Error: SALT must be 16 characters long')
            elif value_error.args[0] == 'AES key must be either 16, 24, or 32 bytes long':
                raise ValueError(
                    'Encryption Error: Encryption key must be either 16, 24, or 32 characters long')
            else:
                raise ValueError(value_error)

    def decrypt(self, enc_str, str_key):
        try:
            aes_obj = AES.new(str_key.encode('utf8'), AES.MODE_CFB, self.salt)
            str_tmp = b64decode(enc_str.encode(self.enc_dec_method))
            str_dec = aes_obj.decrypt(str_tmp)
            mret = str_dec.decode(self.enc_dec_method)
            return mret
        except ValueError as value_error:
            if value_error.args[0] == 'IV must be 16 bytes long':
                raise ValueError(
                    'Decryption Error: SALT must be 16 characters long')
            elif value_error.args[0] == 'AES key must be either 16, 24, or 32 bytes long':
                raise ValueError(
                    'Decryption Error: Encryption key must be either 16, 24, or 32 characters long')
            else:
                raise ValueError(value_error)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="PasswdUtil")
    parser.add_argument("-p", "--password", required=True,
                        help="Password string or encrypted password string")
    parser.add_argument("-k", "--key", required=True,
                        help="Key for encrypt/decrypt")
    parser.add_argument("-d", "--isdecrypt", action="store_true", required=False,
                        help="If present, decrypt action or encrypt")
    parser.add_argument("-f", "--filemode", action="store_true", required=False,
                        help="Read password from file")
    args = parser.parse_args()

    try:
        crypt = Crypt()
        if args.filemode:
            # Read password from file
            with open(args.password, "r") as f:
                passwd = f.readline().strip()
        else:
                passwd = args.password
        if args.isdecrypt:
            print(crypt.decrypt(passwd, args.key))
        else:
            print(crypt.encrypt(passwd, args.key))
    except Exception as exp:
        print(f"Unexpected errors {exp}")
        sys.exit(1)
