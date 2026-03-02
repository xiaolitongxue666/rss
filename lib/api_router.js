const Router = require('@koa/router');
const router = new Router();

// Folo 等阅读器校验实例时请求此接口；返回格式与 /api/routes 一致，由 api-template 包装为 { status, data, message }
const radarRulesHandler = (ctx) => {
    const { rules } = require('./radar');
    ctx.body = { counter: 1, result: rules };
};
router.get('/radar/rules', radarRulesHandler);
router.get('/api/radar/rules', radarRulesHandler);

router.get('/routes/:name?', (ctx) => {
    const result = {};
    let counter = 0;

    const maintainer = require('./maintainer');
    Object.keys(maintainer).forEach((i) => {
        const path = i;
        const top = path.split('/')[1];

        if (!ctx.params.name || top === ctx.params.name) {
            if (result[top]) {
                result[top].routes.push(path);
            } else {
                result[top] = { routes: [path] };
            }
            counter++;
        }
    });

    ctx.body = { counter, result };
});

module.exports = router;
