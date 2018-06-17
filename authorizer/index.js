const {SSM} = require('aws-sdk');

const ssm = new SSM();

exports.handler = async ({authorizationToken, methodArn}, _, callback) => {
    const tokenRequest = {
        Name: process.env.TOKEN_PATH,
        WithDecryption: true,
    };
    const {Parameter: {Value: expectedToken}} = await ssm.getParameter(tokenRequest).promise();

    if (expectedToken === authorizationToken) {
        callback(null, {
            principalId: 'buildkite',
            policyDocument: {
                Statement: [
                    {
                        Action: 'execute-api:Invoke',
                        Effect: 'Allow',
                        Resource: methodArn,
                    }
                ],
                Version: '2012-10-17',
            },
        });
    } else {
        callback('Invalid token');
    }
};
