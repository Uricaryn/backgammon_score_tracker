module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2018,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    // Relaxed rules for deployment
    "quotes": "off",
    "indent": "off", 
    "max-len": "off",
    "camelcase": "off",
    "comma-dangle": "off",
    "no-trailing-spaces": "off",
    "padded-blocks": "off",
    "arrow-parens": "off",
    "valid-jsdoc": "off",
    "no-unused-vars": "off",
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
