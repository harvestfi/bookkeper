const {deploySwap} = require('../deploy-tools/deploy-tools')
module.exports = async (hre) => {
    return await deploySwap(hre, 'UniSwap')
};
module.exports.tags = ['Swap'];
module.exports.dependencies = [];