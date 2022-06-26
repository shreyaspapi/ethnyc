//import { Button, Card, DatePicker, Divider, Input, Progress, Slider, Spin, Switch, Row, Col } from "antd";
import React, { useState } from "react";

import "bootstrap/dist/css/bootstrap.min.css";

import { Card, Row, Col, Button, Alert, Form, InputGroup } from "react-bootstrap";

import { Address, Balance, Events, AddressInput } from "../components";

import { INFURA_ID } from "../constants";

import { ethers } from "ethers";

import { Framework } from "@superfluid-finance/sdk-core";

// Ethers.js provider initialization
const customHttpProvider = new ethers.providers.InfuraProvider("rinkeby", INFURA_ID);

//where the Superfluid logic takes place
async function createNewFlow(recipient, flowRate, provider) {
  console.log("creating new flow");
  console.log(recipient);
  console.log(flowRate);
  console.log(provider);

  const sf = await Framework.create({
    chainId: 4,
    provider: provider,
  });

  const signer = sf.createSigner({
    privateKey: "ae4b6f52bfbdeadbca2901f6776c0411bdff7b482192fb6743d755a52a1995c3",
    provider: provider,
  });

  //const USDCxContraactAddress = await sf.loadSuperToken("USDCx");
  //const USDCx = "0x0F1D7C55A2B133E000eA10EeC03c774e0d6796e8";

  const fUSDCx = await sf.loadSuperToken("0x0F1D7C55A2B133E000eA10EeC03c774e0d6796e8");

  try {
    const createFlowOperation = sf.cfaV1.createFlow({
      flowRate: flowRate,
      receiver: recipient,
      superToken: fUSDCx.address,
      gasLimit: 1000000000000,
    });

    console.log("Creating your stream...");

    const result = await createFlowOperation.exec(signer);
    console.log(result);

    console.log(
      `Congrats - you've just created a money stream!
    View Your Stream At: https://app.superfluid.finance/dashboard/${recipient}
    Network: Goerli
    Super Token: USDCx
    Sender: 0xDCB45e4f6762C3D7C61a00e96Fb94ADb7Cf27721
    Receiver: ${recipient},
    FlowRate: ${flowRate}
    `,
    );
  } catch (error) {
    console.log(
      "Hmmm, your transaction threw an error. Make sure that this stream does not already exist, and that you've entered a valid Ethereum address!",
    );
    console.error(error);
  }
}

//create a page that says hey
export default function CreateStream({ price, address, readContracts, mainnetProvider, sf }) {
  const [toAddress, setToAddress] = useState("");
  const [flowRate, setFlowRate] = useState("");
  const [flowRateDisplay, setFlowRateDisplay] = useState("");

  function calculateFlowRate(amount) {
    if (typeof Number(amount) !== "number" || isNaN(Number(amount)) === true) {
      alert("You can only calculate a flowRate based on a number");
      return;
    } else if (typeof Number(amount) === "number") {
      if (Number(amount) === 0) {
        return 0;
      }

      const amountInWei = ethers.BigNumber.from(amount);
      const amountPerSec = ethers.utils.formatEther(amountInWei.toString());
      const monthlyFlowRate = amountPerSec * 3600 * 24 * 30;

      // convert monthly flow rate from dai to eth

      return monthlyFlowRate;
    }
  }

  const handleFlowRateChange = e => {
    setFlowRate(() => ([e.target.name] = e.target.value));
    // if (typeof Number(flowRate) === "number") {
    let newFlowRateDisplay = calculateFlowRate(e.target.value);
    setFlowRateDisplay(newFlowRateDisplay.toString());
    // setFlowRateDisplay(() => calculateFlowRate(e.target.value));
    // }
  };

  return (
    <div>
      <Row xs={1} md={2} className="g-4">
        {Array.from({ length: 1 }).map((_, idx) => (
          <Col>
            <Card>
              <Card.Header>
                <Card.Title>Stream {idx + 1}</Card.Title>
              </Card.Header>
              <Card.Body>
                <Card.Title className="d-flex justify-content-start"></Card.Title>
                <div style={{ width: 350, padding: 16, margin: "auto" }}>
                  <h5>Create a new stream to this address:</h5>
                  <AddressInput ensProvider={mainnetProvider} value={toAddress} onChange={setToAddress} />
                  <h5>With this flow rate:</h5>
                  <InputGroup size="sm" className="mb-3">
                    <InputGroup.Text id="inputGroup-sizing-sm">Rate</InputGroup.Text>
                    <Form.Control
                      aria-label="Small"
                      aria-describedby="inputGroup-sizing-sm"
                      name="FlowRate"
                      value={flowRate}
                      onChange={handleFlowRateChange}
                    />
                  </InputGroup>
                  <p>Your flow will be equal to:</p>
                  <p>
                    <b>${flowRateDisplay !== " " ? flowRateDisplay : 0}</b> USDCx/month
                  </p>
                </div>
                <p> Lev Aave link recived</p>
                <p>$0 rcived so far</p>
                <Card.Text className="d-flex justify-content-evenly">
                  <div>
                    <Button variant="primary" onClick={() => createNewFlow(toAddress, flowRate, customHttpProvider)}>
                      Create Stream
                    </Button>
                  </div>
                </Card.Text>
              </Card.Body>
            </Card>
          </Col>
        ))}
      </Row>
    </div>
  );
}
